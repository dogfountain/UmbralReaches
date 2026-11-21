extends Node
## Lava renders (free camera): godot --path . res://zz/lava_shots.tscn  ->  shots/lava_<view>.png
## Waits until LavaWorks has mapped the banks twice (9 s) and poured its falls (3 s).
## Under the Realm (-- --realm) the falls come after the rift module has built: it waits for them
## (up to 60 s), then 9 s more for the second bank mapping; views include the Crossing.
var WAIT := 10.5
var t := 0.0
var i := -1
var cam: Camera3D
var views: Array = [
	["overview", Vector3(-24.0, 10.0, -48.0), Vector3(4.0, -15.5, -80.0)],
	["bank", Vector3(-6.0, -9.0, -52.0), Vector3(-12.0, -15.5, -66.0)],
	["under_summit", Vector3(-14.0, -6.0, -78.0), Vector3(2.0, -15.5, -100.0)],
	["from_stair", Vector3(6.2, 9.4, -57.3), Vector3(14.0, -15.5, -72.0)],
]
var realm_views: Array = [
	["rift_rim", Vector3(10.0, 8.0, 0.0), Vector3(-6.0, 0.0, -40.0)],
	["rift_crossing", Vector3(14.0, 30.0, 8.0), Vector3(-6.0, 6.0, -45.0)],
	["rift_crag", Vector3(14.0, 6.0, -36.0), Vector3(-6.0, 8.0, -58.0)],
	["rift_from_landing", Vector3(2.0, 29.8, -64.0), Vector3(-6.0, 0.0, -25.0)],
	["rift_west_bank", Vector3(12.0, -7.0, -30.0), Vector3(-17.0, -12.0, -56.0)],
]
var _waited := false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	if not _waited:
		var lw0 := get_tree().root.find_child("LavaWorks", true, false)
		var poured := lw0 != null and lw0.get_children().any(func(c: Node) -> bool: return String(c.name).begins_with("LavaFall"))
		if poured or t > 60.0:
			_waited = true
			WAIT = t + 9.0
			views = realm_views + views.slice(0, 3)
		return
	if t < WAIT:
		return
	if cam == null:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
		var lw := get_tree().root.find_child("LavaWorks", true, false)
		print("LAVA_SHOTS works=", lw != null)
		if lw:
			var k := 0
			for c in lw.get_children():
				if c is MeshInstance3D and String(c.name).begins_with("LavaFall") and not String(c.name).begins_with("LavaFallPool"):
					var bb := (c as MeshInstance3D).global_transform * (c as MeshInstance3D).get_aabb()
					var mid := bb.get_center()
					var toward := Vector3(-signf(mid.x), 0, 0)          # stand over the river, facing the wall
					views.append(["fall_%d" % k, mid + toward * 16.0 + Vector3(0, 1.0, 9.0), mid])
					views.append(["fall_%d_lip" % k, Vector3(mid.x, bb.end.y, mid.z) + toward * 5.0 + Vector3(0, 3.0, 5.0), Vector3(mid.x - toward.x * 2.0, bb.end.y - 1.0, mid.z)])
					k += 1
				elif c is MeshInstance3D and String(c.name).begins_with("LavaFallPool"):
					var at := (c as Node3D).global_position
					var toward2 := Vector3(-signf(at.x), 0, 0)
					views.append(["fall_base_%d" % views.size(), at + toward2 * 9.0 + Vector3(0, 4.0, 6.0), at + Vector3.UP * 2.0])
		cam = Camera3D.new()
		cam.fov = 62.0
		cam.far = 400.0
		get_tree().root.add_child(cam)
		cam.current = true
		_next()
		return
	if t > WAIT + 0.6 * float(i + 1):
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/lava_%s.png" % views[i][0]))
		print("LAVA_SHOT ", views[i][0])
		_next()
func _next() -> void:
	i += 1
	if i >= views.size():
		print("LAVA_SHOTS done")
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())
		return
	cam.global_position = views[i][1]
	cam.look_at(views[i][2])

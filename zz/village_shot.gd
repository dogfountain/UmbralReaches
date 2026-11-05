extends Node
## Village renders with the colour grade ON (village agent). Never writes the save (Travel._busy,
## exits with OS.kill).
##   godot --path . res://zz/village_shot.tscn -- --name=n [--at=x,y,z --look=x,y,z]
##     [--focus=<villager id>|@anchor --off=x,y,z [--lookoff=x,y,z]]  camera relative to a villager / anchor
##     [--times=12,13]  frames (seconds after load)   [--restore=all]  progress set in memory first
##     [--clock=0.3]  village clock (fraction of the night)   [--fov=50]
## Writes shots/village_<name>[_i].png.
var t := 0.0
var cam: Camera3D
var at := Vector3(0, 4, 18)
var look := Vector3(0, 1, 35)
var focus := ""
var off := Vector3(0, 1.6, -2.5)
var lookoff := Vector3(0, 1.2, 0)
var nm := "shot"
var times: Array[float] = [12.0]
var ti := 0
var clock := -1.0
var fov := 55.0
var talk := ""
var talked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		var v := a.split("=")
		if v.size() < 2:
			continue
		var p := v[1].split(",")
		match v[0]:
			"--at": at = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--look": look = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--focus": focus = v[1]
			"--off": off = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--lookoff": lookoff = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--name": nm = v[1]
			"--clock": clock = float(v[1])
			"--fov": fov = float(v[1])
			"--talk": talk = v[1]
			"--times":
				times.clear()
				for x in p:
					times.append(float(x))
			"--restore":
				Travel.seals_broken = {"henge": true, "oss_gallery": true, "summit": true}
				Travel.bosses_slain = {"thornwarden": true, "bone_abbot": true, "ascended_warden": true}
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _village() -> Node:
	return get_tree().root.find_child("Village", true, false)


func _process(d: float) -> void:
	t += d
	var v := _village()
	if cam == null and v != null and v.has_meta("village_done") and t > 7.0:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if String(c.name) != "Grade" and (talk == "" or String(c.name) == "HUD"):
				(c as CanvasLayer).visible = false
		if clock >= 0.0:
			v.set("clock", clock * 600.0)
		cam = Camera3D.new()
		cam.fov = fov
		cam.far = 400.0
		get_tree().root.add_child(cam)
		cam.current = true
	if cam != null:
		_aim(v)
	if cam != null and talk != "" and not talked and t > 8.5:
		talked = true
		var who := (v.get("villagers") as Dictionary).get(talk) as Node
		if who:
			who.call("interact", get_tree().get_first_node_in_group(Groups.PLAYER))
	if cam != null and ti < times.size() and t > times[ti]:
		var suffix := "" if times.size() == 1 else "_%d" % ti
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/village_%s%s.png" % [nm, suffix]))
		print("VILLAGE SHOT %s%s draws %d prims %d fps %d" % [nm, suffix, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.TIME_FPS)])
		ti += 1
	if ti >= times.size():
		print("VILLAGE SHOT saved ", nm)
		OS.kill(OS.get_process_id())
	if t > 120.0:
		OS.kill(OS.get_process_id())


func _aim(v: Node) -> void:
	if focus == "":
		cam.global_position = at
		cam.look_at(look)
		return
	var p := Vector3.INF
	var yaw := 0.0
	if focus.begins_with("@"):
		p = v.call("anchor", focus)
	else:
		var n := (v.get("villagers") as Dictionary).get(focus) as Node3D
		if n:
			p = n.global_position
			yaw = n.rotation.y
	if p == Vector3.INF:
		return
	var b := Basis(Vector3.UP, yaw)
	cam.global_position = p + b * off
	cam.look_at(p + lookoff)

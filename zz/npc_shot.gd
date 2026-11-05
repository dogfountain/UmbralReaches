extends Node
## In-game NPC renders with the colour grade ON (npc agent): free camera, frame sequences for
## animation, optional forced bar trips. Never writes the save (Travel._busy; exits with OS.kill).
##   godot --path . res://zz/npc_shot.tscn -- --name=n --at=x,y,z --look=x,y,z
##     [--focus=<villager id>|patron<i>|keep --off=x,y,z --lookoff=x,y,z]  camera follows an NPC
##     [--times=10,10.2,10.4 | --seq=10:0.25:8]  frames (seconds after the village is up)
##     [--trip]  the bar-going patrons get up at once   [--clock=0.3]  village clock (night fraction)
##     [--player=x,y,z]  park the wanderer there (NPCs look at him)   [--fov=50]
## Writes shots/npc_<name>[_i].png and prints draws/prims per frame.

var t := 0.0
var cam: Camera3D
var at := Vector3(14.0, 1.0, 26.5)
var look := Vector3(15.0, 0.4, 30.0)
var focus := ""
var off := Vector3(0, 1.6, -2.5)
var lookoff := Vector3(0, 1.2, 0)
var nm := "shot"
var times: Array[float] = [3.0]
var ti := 0
var clock := -1.0
var fov := 55.0
var trip := false
var player_at := Vector3.INF
var t0 := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a == "--trip":
			trip = true
		var v := a.split("=")
		if v.size() < 2:
			continue
		var p := v[1].split(",")
		match v[0]:
			"--at": at = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--look": look = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--player": player_at = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--focus": focus = v[1]
			"--off": off = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--lookoff": lookoff = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--name": nm = v[1]
			"--clock": clock = float(v[1])
			"--fov": fov = float(v[1])
			"--times":
				times.clear()
				for x in p:
					times.append(float(x))
			"--seq":
				var q := v[1].split(":")
				times.clear()
				for k in int(q[2]):
					times.append(float(q[0]) + float(q[1]) * float(k))
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _village() -> Node:
	return get_tree().root.find_child("Village", true, false)


func _find(n: String) -> Node3D:
	if n == "keep":
		return get_tree().get_first_node_in_group("keep") as Node3D
	if n.begins_with("patron"):
		return get_tree().root.find_child("Patron" + n.trim_prefix("patron"), true, false) as Node3D
	var v := _village()
	return (v.get("villagers") as Dictionary).get(n) as Node3D if v else null


func _process(d: float) -> void:
	t += d
	var v := _village()
	if cam == null and v != null and v.has_meta("village_done") and t > 7.0:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if String(c.name) != "Grade":
				(c as CanvasLayer).visible = false
		if clock >= 0.0:
			v.set("clock", clock * 600.0)
		if trip:
			for n in get_tree().root.find_children("Patron*", "", true, false):
				if bool(n.get("wanders")):
					n.set("_trip_wait", 0.0)
					n.set("_act", "idle")
		cam = Camera3D.new()
		cam.fov = fov
		cam.far = 400.0
		get_tree().root.add_child(cam)
		cam.current = true
		t0 = t
	if cam == null:
		return
	if player_at != Vector3.INF:
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if pl:
			pl.global_position = player_at
			if "velocity" in pl:
				pl.set("velocity", Vector3.ZERO)
	_aim()
	if ti < times.size() and t - t0 > times[ti]:
		var suffix := "" if times.size() == 1 else "_%d" % ti
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/npc_%s%s.png" % [nm, suffix]))
		print("NPC SHOT %s%s draws %d prims %d fps %d" % [nm, suffix, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.TIME_FPS)])
		ti += 1
	if ti >= times.size():
		print("NPC SHOT saved ", nm)
		OS.kill(OS.get_process_id())
	if t > 180.0:
		OS.kill(OS.get_process_id())


func _aim() -> void:
	if focus == "":
		cam.global_position = at
		cam.look_at(look)
		return
	var n := _find(focus)
	if n == null:
		cam.global_position = at
		cam.look_at(look)
		return
	var b := Basis(Vector3.UP, n.rotation.y)
	cam.global_position = n.global_position + b * off
	cam.look_at(n.global_position + lookoff)

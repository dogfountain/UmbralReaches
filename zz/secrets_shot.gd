extends Node
## Secrets renders with the colour grade ON, several views per run, with the boss/secret state set
## in memory first (nothing is saved: the save files are restored and the process is killed).
##   godot --path . res://zz/secrets_shot.tscn -- --views="name@ax,ay,az@lx,ly,lz;name2@..." \
##       [--bosses=thornwarden,bone_abbot,ascended_warden] [--solve=all|bells,penitent,...] [--tag=x]
##       [--settle=2.5] [--sky]  (--sky: also keep the sky calm transition at its end state)
## Writes shots/secrets_<tag>_<name>.png. Shots before/after a boss: run twice with and without --bosses.
const Secrets := preload("res://core/life/secrets/secrets.gd")
var t := 0.0
var cam: Camera3D
var views: Array = []
var vi := 0
var tag := "s"
var settle := 2.5
var main: Node
var ready_t := -1.0
var view_t := -1.0
var _saved := {}


func _ready() -> void:
	_backup()
	Travel.set("_busy", true)           # renders never write the save
	var bosses: Array = []
	var solve: Array = []
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"--views":
				for s in kv[1].split(";", false):
					var p := s.split("@")
					var a3 := p[1].split(",")
					var l3 := p[2].split(",")
					views.append([p[0], Vector3(float(a3[0]), float(a3[1]), float(a3[2])), Vector3(float(l3[0]), float(l3[1]), float(l3[2]))])
			"--bosses":
				bosses = Array(kv[1].split(",", false))
			"--solve":
				solve = Array(kv[1].split(",", false))
			"--tag":
				tag = kv[1]
			"--settle":
				settle = float(kv[1])
	Travel.bosses_slain.clear()
	for b in bosses:
		Travel.bosses_slain[b] = true
	var st := Travel.system_state("secrets")
	st.clear()
	if not solve.is_empty():
		Secrets.debug_solve(st, solve)
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _backup() -> void:
	pass


## Travel._busy keeps this run from writing the save at all, so nothing is written back either
## (writing the copy back would clobber a save another test is using at the same time).
func _restore_and_quit() -> void:
	OS.kill(OS.get_process_id())


func _process(d: float) -> void:
	t += d
	if t > 150.0:
		print("SECRETS_SHOT timeout")
		_restore_and_quit()
	if ready_t < 0.0:
		if main != null and main.is_inside_tree() and main.has_meta("realm_done"):
			ready_t = t
		return
	if cam == null:
		if t - ready_t < 2.0:
			return
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if String(c.name) != "Grade":
				(c as CanvasLayer).visible = false
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if pl:
			pl.visible = false
		cam = Camera3D.new()
		cam.fov = 60.0
		cam.far = 400.0
		get_tree().root.add_child(cam)
		cam.current = true
		view_t = -1.0
	if vi >= views.size():
		print("SECRETS_SHOT done ", tag)
		_restore_and_quit()
		return
	var v: Array = views[vi]
	if view_t < 0.0:
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if String(c.name) != "Grade":
				(c as CanvasLayer).visible = false     # HUD layers built late (tide sky, banners) too
		cam.global_position = v[1]
		cam.look_at(v[2])
		var pl2 := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if pl2:
			# streaming and culling follow the player: park it (frozen, hidden) under the camera
			pl2.process_mode = Node.PROCESS_MODE_DISABLED
			var sp := (pl2 as Node3D).get_world_3d().direct_space_state
			var c: Vector3 = v[1]
			pl2.global_position = Vector3(c.x, RealmLayout.ground(sp, c.x, c.z) + 0.1, c.z)
		view_t = t
		return
	if t - view_t > settle:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/secrets_%s_%s.png" % [tag, v[0]]))
		print("SECRETS_SHOT saved ", tag, "_", v[0])
		vi += 1
		view_t = -1.0

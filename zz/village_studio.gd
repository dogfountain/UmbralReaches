extends Node3D
## Village studio (village agent): the cast built in an empty lit set, for model review.
##   godot --path . res://zz/village_studio.tscn -- [--only=hild,fennick] [--view=line|face|back] [--name=x] [--pose=idle|walk]
##   headless: builds every rig and prints vertex/triangle counts, then quits.
## Writes shots/village_studio_<name>.png. Never touches the save.
const Rig := preload("res://core/life/village/villager_rig.gd")
const Cast := preload("res://core/life/village/village_cast.gd")

var t := 0.0
var nm := "line"
var view := "line"
var pose := "idle"
var only: Array = []
var rigs: Array = []
var shot := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.split("=")
		if v.size() < 2:
			continue
		match v[0]:
			"--only": only = Array(v[1].split(","))
			"--view": view = v[1]
			"--name": nm = v[1]
			"--pose": pose = v[1]
	var ids: Array = Cast.CAST.keys() if only.is_empty() else only
	var x := -float(ids.size() - 1) * 0.45
	for id: String in ids:
		var opts: Dictionary = (Cast.CAST[id].rig as Dictionary).duplicate()
		opts["name"] = id
		var t0 := Time.get_ticks_msec()
		var r: Node3D = Rig.create(opts)
		add_child(r)
		r.position = Vector3(x, 0, 0)
		x += 0.9
		var mi: MeshInstance3D = r.get("mesh_instance")
		var m := mi.mesh as ArrayMesh
		var tris := 0
		for s in m.get_surface_count():
			tris += m.surface_get_array_index_len(s) / 3
		print("STUDIO %s verts %d tris %d lods %d in %d ms (top %.2f m)" % [id, m.surface_get_array_len(0), tris, m.surface_get_blend_shape_count() if false else 0, Time.get_ticks_msec() - t0, r.call("head_top")])
		rigs.append(r)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	get_window().size = Vector2i(1600, 1000)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.42, 0.66)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.5, 0.7, 1.0)
	moon.light_energy = 0.7
	moon.rotation = Vector3(-0.7, 0.6, 0)
	moon.shadow_enabled = true
	add_child(moon)
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.6, 0.3)
	key.light_energy = 2.2
	key.omni_range = 9.0
	key.position = Vector3(1.5, 1.8, -2.4)
	add_child(key)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.19, 0.17)
	floor_mi.material_override = fm
	add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var n := float(rigs.size())
	match view:
		"face":
			cam.position = Vector3(0, 1.62, -0.9 - n * 0.4)
			cam.look_at(Vector3(0, 1.5, 0))
		"back":
			cam.position = Vector3(0.6, 1.4, 2.0 + n * 0.55)
			cam.look_at(Vector3(0, 0.9, 0))
		_:
			cam.position = Vector3(0.3, 1.25, -2.2 - n * 0.55)
			cam.look_at(Vector3(0, 0.85, 0))
	cam.current = true


func _process(d: float) -> void:
	t += d
	for r: Node3D in rigs:
		_pose(r, t)
	if not shot and t > 1.5:
		shot = true
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/village_studio_%s.png" % nm))
		print("STUDIO saved ", nm)
		get_tree().quit()


func _pose(r: Node3D, time: float) -> void:
	r.call("reset")
	if pose == "walk":
		var ph := time * 1.6
		for side in 2:
			var s := sin(TAU * ph + PI * float(side))
			var c := cos(TAU * ph + PI * float(side))
			r.call("q", 11 + side * 2, Quaternion(Vector3.RIGHT, 0.36 * s))
			r.call("q", 12 + side * 2, Quaternion(Vector3.RIGHT, -(0.08 + 0.7 * maxf(c, 0.0))))
			r.call("q", 5 + side * 3, Quaternion(Vector3.RIGHT, -0.3 * s))
			r.call("q", 6 + side * 3, Quaternion(Vector3.RIGHT, 0.25))
	else:
		for side in 2:
			r.call("q", 5 + side * 3, Quaternion(Vector3.FORWARD, (0.08 if side == 0 else -0.08)))
			r.call("q", 6 + side * 3, Quaternion(Vector3.RIGHT, 0.35))
	r.call("apply")
	r.call("update_glow")

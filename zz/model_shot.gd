extends Node3D
## Studio render of one model (neutral light, grey backdrop): front, 3/4, side.
##   godot --path . res://zz/model_shot.tscn -- --model=res://art/models/x.glb --name=n
##   procedural dwarf: -- --rig --model=seated|standing --name=n (seed from the name; "keep" = apron)
var t := 0.0
var cam: Camera3D
var model: Node3D
var nm := "model"
var views := [[Vector3(0, 0.75, -2.1), 0.0], [Vector3(1.5, 0.85, -1.5), 0.0], [Vector3(2.1, 0.75, 0), 0.0]]
var vi := 0
func _ready() -> void:
	var path := ""
	var rig := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="): path = a.trim_prefix("--model=")
		elif a.begins_with("--name="): nm = a.trim_prefix("--name=")
		elif a == "--rig": rig = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.33, 0.36)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.4, 0)
	fill.light_energy = 0.5
	add_child(fill)
	if rig:
		model = DwarfRig.make({"seated": path != "standing", "seed": int(nm.hash()) % 1000, "apron": nm.contains("keep")})
		add_child(model)
	else:
		model = (load(path) as PackedScene).instantiate()
		add_child(model)
	cam = Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	cam.current = true
func _process(d: float) -> void:
	t += d
	if t < 0.5: return
	if vi < views.size():
		var v: Array = views[vi]
		cam.global_position = v[0]
		cam.look_at(Vector3(0, 0.75, 0))
		if t > 0.5 + 0.3 * float(vi + 1):
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/model_%s_%d.png" % [nm, vi]))
			vi += 1
	else:
		print("MODEL saved ", nm)
		get_tree().quit()

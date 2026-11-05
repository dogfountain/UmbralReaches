extends Node3D
## Studio renders of realm flora kinds (core/world/realm/tree_gen.gd) in a row under moonlight.
##   godot --path . res://zz/tree_shot.tscn -- --kinds=oak_0,oak_1 --name=oaks [--night] [--y=2] [--dist=1.0]
## -> shots/tree_<name>.png ; prints tri counts per kind and build time.
const TreeGen := preload("res://core/world/realm/tree_gen.gd")
var t := 0.0
var nm := "trees"
var shot := false
func _ready() -> void:
	var kinds: PackedStringArray = ["oak_0"]
	var night := false
	var ylook := -1.0
	var dist_k := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kinds="): kinds = a.trim_prefix("--kinds=").split(",")
		elif a.begins_with("--name="): nm = a.trim_prefix("--name=")
		elif a == "--night": night = true
		elif a.begins_with("--y="): ylook = float(a.trim_prefix("--y="))
		elif a.begins_with("--dist="): dist_k = float(a.trim_prefix("--dist="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	get_window().size = Vector2i(1600, 1000)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.07, 0.13) if night else Color(0.3, 0.32, 0.36)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.38, 0.6) if night else Color(0.55, 0.55, 0.6)
	e.ambient_light_energy = 0.5 if night else 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.75, 0.7, 0)
	sun.light_energy = 1.0 if night else 1.4
	sun.light_color = Color(0.56, 0.64, 1.0) if night else Color(1, 1, 1)
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.4, 0)
	fill.light_energy = 0.35
	add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.13, 0.11)
	ground.material_override = gm
	add_child(ground)
	var x := 0.0
	var maxh := 0.0
	var tot := 0
	var t0 := Time.get_ticks_msec()
	var widths: Array[float] = []
	for k in kinds:
		var d: Dictionary = TreeGen.kind(k)
		widths.append(maxf(float(d.spread), 0.6) * 2.0 + 1.0)
		maxh = maxf(maxh, float(d.h))
		tot += int(d.tris)
		print("TREE %-10s tris %6d cards %6d  h %5.1f  r %.2f  spread %.1f" % [k, d.tris, d.card_tris, d.h, d.r, d.spread])
	print("TREE built %d kinds in %d ms, %d tris" % [kinds.size(), Time.get_ticks_msec() - t0, tot])
	var total_w := 0.0
	for w in widths: total_w += w
	x = -total_w * 0.5
	for i in kinds.size():
		var d: Dictionary = TreeGen.kind(kinds[i])
		x += widths[i] * 0.5
		for key in ["solid", "cards"]:
			if d[key] != null:
				var mi := MeshInstance3D.new()
				mi.mesh = d[key]
				mi.position = Vector3(x, 0, 0)
				add_child(mi)
		x += widths[i] * 0.5
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var span := maxf(total_w, maxh * 1.4) * dist_k
	var yl := maxh * 0.5 if ylook < 0.0 else ylook
	cam.position = Vector3(0, yl + span * 0.12, span * 1.25 + 1.0)
	cam.look_at(Vector3(0, yl, 0))
	cam.current = true
func _process(d: float) -> void:
	t += d
	if t > 1.5 and not shot:
		shot = true
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/tree_%s.png" % nm))
		print("TREE saved ", nm)
		get_tree().quit()

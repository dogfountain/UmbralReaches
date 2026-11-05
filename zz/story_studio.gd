extends Node3D
## Tavern NPC studio: a lit set with a table, benches, a chair, the counter and the duckboard at
## the Tavern's real heights, two paired patrons, a chair sitter, the bar regular and the keep,
## animated as in game; the game's colour grade on top (world/post/grade_material.tres).
##   godot --path . res://zz/story_studio.tscn -- [--name=x] [--times=1,2,3] [--views=table,face,keep,bar] [--nograde]
## -> shots/story_<name>_<view>_<i>.png
const DwarfLook := preload("res://core/npc/dwarf_look.gd")
var t := 0.0
var cam: Camera3D
var nm := "studio"
var times: Array[float] = [2.0]
var views: Array[String] = ["table", "face", "keep", "bar", "chair"]
var ti := 0
var vi := 0
var grade := true
var patrons: Array[DwarfNpc] = []
var keep: Bartender
const VIEWS := {
	"table": [Vector3(1.9, 1.35, 1.2), Vector3(0.0, 0.85, 0.0)],
	"face": [Vector3(-0.35, 1.38, 1.45), Vector3(-0.35, 1.32, 0.85)],
	"face2": [Vector3(0.4, 1.4, -1.35), Vector3(0.4, 1.32, -0.85)],
	"keep": [Vector3(0.6, 1.5, 2.6), Vector3(0.6, 1.3, 4.25)],
	"bar": [Vector3(-1.4, 1.35, 2.2), Vector3(-0.2, 1.0, 3.2)],
	"chair": [Vector3(-1.6, 1.25, 1.2), Vector3(-1.32, 0.8, 0.0)],
	"wide": [Vector3(3.2, 2.0, -1.8), Vector3(0.0, 0.8, 1.5)],
	"line": [Vector3(0.0, 1.0, -3.6), Vector3(0.0, 0.85, -6.0)],
	"line_close": [Vector3(-0.75, 1.35, -5.15), Vector3(-0.75, 1.33, -6.0)],
	"line_close2": [Vector3(0.75, 1.35, -5.15), Vector3(0.75, 1.33, -6.0)],
	"line_back": [Vector3(0.0, 1.3, -8.2), Vector3(0.0, 0.85, -6.0)],
	"line_side": [Vector3(-2.6, 1.1, -6.0), Vector3(0.0, 0.85, -6.0)],
}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.split("=")
		if a == "--nograde":
			grade = false
		if a == "--nolod":
			get_viewport().mesh_lod_threshold = 0.0
		if v.size() < 2:
			continue
		match v[0]:
			"--name": nm = v[1]
			"--times":
				times.clear()
				for x in v[1].split(","): times.append(float(x))
			"--views":
				views.clear()
				for x in v[1].split(","): views.append(x)
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.04, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.45, 0.85)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.2
	env.environment = e
	add_child(env)
	for l: Array in [[Vector3(-1.0, 2.2, -4.2), 2.2, 5.0], [Vector3(1.6, 1.4, -4.6), 1.0, 4.0], [Vector3(-1.5, 2.2, 2.0), 1.2, 6.0], [Vector3(1.5, 1.9, 3.6), 1.4, 5.0]]:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.62, 0.32)
		o.light_energy = l[1]
		o.omni_range = l[2]
		add_child(o)
		o.position = l[0]
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.73, 1.0)
	moon.light_energy = 0.25
	moon.rotation = Vector3(-0.9, 0.7, 0.0)
	add_child(moon)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.19, 0.11)
	wood.roughness = 0.8
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.4, 0.38, 0.36)
	_box(Vector3(0, -0.05, 1.5), Vector3(8, 0.1, 8), stone)
	# table centred at the origin (x along), benches 0.85 off, a chair at the -x end
	_box(Vector3(0, 0.76, 0), Vector3(1.8, 0.08, 0.9), wood)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(s * 0.7, 0.36, 0), Vector3(0.12, 0.72, 0.6), wood)
		_box(Vector3(0, 0.445, s * 0.85), Vector3(1.7, 0.05, 0.28), wood)
		for ex: float in [-0.7, 0.7]:
			_box(Vector3(ex, 0.21, s * 0.85), Vector3(0.1, 0.42, 0.2), wood)
	_box(Vector3(-1.32, 0.445, 0), Vector3(0.48, 0.05, 0.5), wood)
	_box(Vector3(-1.54, 0.78, 0), Vector3(0.04, 0.66, 0.46), wood)
	# counter: front face z 3.2, top 1.0..1.08 overhanging to 3.1..3.83; duckboard behind; foot step
	_box(Vector3(0, 0.5, 3.475), Vector3(4.0, 1.0, 0.55), wood)
	_box(Vector3(0, 1.04, 3.465), Vector3(4.1, 0.08, 0.73), wood)
	_box(Vector3(0, 0.15, 4.11), Vector3(4.0, 0.3, 0.56), wood)
	_box(Vector3(0, 0.11, 2.955), Vector3(4.0, 0.22, 0.39), wood)
	_box(Vector3(0, 1.32, 4.43), Vector3(4.0, 0.05, 0.35), wood)
	var spots := [
		[Vector3(-0.35, 0, 0.85), 0.0, "helm", 911, -0.4, false],
		[Vector3(0.4, 0, -0.85), PI, "hood", 948, -0.4, false],
		[Vector3(-1.32 + 0.06, 0, 0), -PI * 0.5, "", 985, -0.36, true],
	]
	for i in spots.size():
		var sp: Array = spots[i]
		var d := DwarfNpc.new()
		d.seed_n = sp[3]
		d.facing = sp[1]
		d.hat = sp[2]
		d.table_edge = sp[4]
		d.tuck = sp[5]
		add_child(d)
		d.global_position = sp[0]
		patrons.append(d)
	patrons[0].partner = patrons[1]
	patrons[0].leader = true
	patrons[1].partner = patrons[0]
	var b := DwarfNpc.new()
	b.seed_n = 911 + 8 * 37
	b.facing = PI
	b.seated = false
	b.hat = "hood"
	b.lean_bar = true
	b.table_top = 1.08 - 0.22
	b.table_edge = -(3.1 - 2.88)
	add_child(b)
	b.global_position = Vector3(-0.2, 0.22, 2.88)
	patrons.append(b)
	keep = Bartender.new()
	keep.lane_x = Vector2(-1.5, 1.5)
	keep.lane_z = 4.48
	keep.bar_y = 1.08
	keep.bar_z = 3.83 - 0.73 + 0.73
	keep.bar_z = 3.83
	keep.keg = Vector3(2.4, 0.48, 4.2)
	keep.regular = b
	add_child(keep)
	keep.global_position = Vector3(0.6, 0.3, 4.48)
	# a line-up of standing dwarves at z -6 facing the camera (+z), for model checks
	var hats := ["helm", "hood", "cap", "bare", "bare"]
	for i in 5:
		var r := DwarfRig.make({"seated": false, "seed": 2000 + i * 13, "hat": hats[i], "apron": i == 4, "rag": i == 4})
		add_child(r)
		r.position = Vector3(-1.5 + 0.75 * float(i), 0, -6.0)
		r.rotation.y = PI
	if grade:
		var cl := CanvasLayer.new()
		var cr := ColorRect.new()
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.material = load("res://world/post/grade_material.tres")
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(cr)
		add_child(cl)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	_view()


func _box(at: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	add_child(mi)
	mi.position = at


func _view() -> void:
	var v: Array = VIEWS.get(views[vi], VIEWS["table"])
	cam.global_position = v[0]
	cam.look_at(v[1])


func _process(d: float) -> void:
	t += d
	if ti < times.size() and t > times[ti]:
		var path := "res://shots/story_%s_%s_%d.png" % [nm, views[vi], ti]
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		ti += 1
		if ti >= times.size():
			ti = 0
			vi += 1
			if vi >= views.size():
				print("STUDIO done ", nm)
				get_tree().quit()
				return
			t = 0.0
			_view()

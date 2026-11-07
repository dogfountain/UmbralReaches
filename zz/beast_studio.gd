extends Node
## Beast studio (windowed): one species at a time on a flat moonlit lawn, the real creature shader and
## MultiMesh path, at 6 / 12 / 20 m, side and three-quarter, grazing and walking.
##   godot --path . res://zz/beast_studio.tscn -- --tag=x --only=deer,stag,fox [--sheet]
## Writes <OUT>/studio_<kind>_<tag>.png (a sheet of the views) and, with --full, each view alone.
const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const OUT := "/private/tmp/claude-501/-Users-luke-UmbralReaches/968888c4-6238-49b1-a0f8-2ba292b49c0a/scratchpad/wave6/beasts/"
var tag := "x"
var only: Array = ["deer", "stag", "elk", "fox", "hare", "boar"]
var full := false
var cam: Camera3D
var t := 0.0
var step := 0
var mmi: MultiMeshInstance3D
var views: Array = []
var shots: Array[Image] = []
var kinds: Array = []
var ki := 0
var vi := 0
var wait := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
		elif a == "--full":
			full = true
	kinds = only
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.25, 0.4)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_color = Color(0.72, 0.8, 1.0)
	sun.light_energy = 1.0
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.2, 0.15)
	gm.roughness = 1.0
	g.material_override = gm
	add_child(g)
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 200
	add_child(cam)
	cam.current = true
	# views: [distance, yaw (0 = side-on from the left), grazing 0/walking 1, label]
	views = [[3.2, 90.0, 1], [3.2, 40.0, 0], [6.0, 90.0, 0], [6.0, 40.0, 1], [12.0, 90.0, 1], [20.0, 30.0, 0]]
	_next_kind()


func _next_kind() -> void:
	if mmi != null:
		mmi.queue_free()
		mmi = null
	if ki >= kinds.size():
		get_tree().quit()
		return
	var k: String = kinds[ki]
	mmi = LifeKit.group(k, 1)
	add_child(mmi)
	mmi.multimesh.custom_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 6, 10))
	vi = 0
	shots.clear()
	wait = 0
	_set_view()


func _set_view() -> void:
	var v: Array = views[vi]
	var k: String = kinds[ki]
	var sc := 1.75 if k == "elk" else (0.45 if (k == "fox" or k == "hare") else 1.0)
	if k == "boar":
		sc = 0.8
	var d: float = v[0] * (0.5 if k == "fox" or k == "hare" else (0.7 if k == "boar" else 1.0))
	var yaw := deg_to_rad(float(v[1]))
	var xf := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	mmi.multimesh.set_instance_transform(0, xf)
	var graze: bool = int(v[2]) == 0
	var gait := 1.2
	# custom: x moving, y head yaw, z gait, w head pitch
	mmi.multimesh.set_instance_custom_data(0, Color(0.0 if graze else 1.0, 0.0, gait, -1.0 if (graze and k != "hare") else 0.0))
	var eye := Vector3(sin(yaw) * d, 1.4 if d < 8.0 else 1.6, cos(yaw) * d) * 1.0
	cam.global_position = eye
	cam.look_at(Vector3(0, 0.7 * minf(sc, 1.2) + (0.2 if k == "elk" else 0.0), 0))


func _process(dt: float) -> void:
	t += dt
	wait += 1
	if wait < 4:
		return
	var img := get_viewport().get_texture().get_image()
	var k: String = kinds[ki]
	if full:
		img.save_png(OUT + "studio_%s_%d_%s.png" % [k, vi, tag])
	var small := img.duplicate() as Image
	small.resize(640, 360)
	shots.append(small)
	vi += 1
	wait = 0
	if vi >= views.size():
		var sheet := Image.create(1920, 720, false, Image.FORMAT_RGB8)
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, 640, 360), Vector2i((i % 3) * 640, (i / 3) * 360))
		sheet.save_png(OUT + "studio_%s_%s.png" % [k, tag])
		print("STUDIO ", k)
		ki += 1
		_next_kind()
	else:
		_set_view()

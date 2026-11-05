extends Node3D
## Studio renders of the people (models pass): the tavern dwarves (DwarfRig) and a spread of
## Hearthward's villagers (VillagerRig, from the cast), each as a face close-up and a full-length
## shot, under a moonlit rig with a warm lantern fill (as combat_studio lights the enemies).
##   godot --path . res://zz/npc_studio.tscn -- --tag=before [--only=hild,dwarf_a]
## -> shots/npc/<tag>_<id>_face.png, _full.png, and shots/npc/<tag>_sheet.png (faces over bodies)

const Cast := preload("res://core/life/village/village_cast.gd")
const VRig := preload("res://core/life/village/villager_rig.gd")

const VILLAGERS := ["hild", "fennick", "nan", "ruan", "elspeth", "cadoc"]
const DWARVES := {"dwarf_keep": {"seated": false, "seed": 5150, "apron": true, "hat": "bare", "rag": true},
	"dwarf_patron": {"seated": false, "seed": 7023, "hat": "hood"}}

var tag := "studio"
var only: PackedStringArray = []
var cam: Camera3D
var _shots: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/npc"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.05, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.42, 0.7)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.2
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.73, 1.0)
	moon.light_energy = 1.05
	moon.shadow_enabled = true
	moon.rotation = Vector3(-0.75, 0.9, 0)
	add_child(moon)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.62, 0.3)
	lamp.light_energy = 2.2
	lamp.omni_range = 9.0
	lamp.position = Vector3(-1.6, 1.6, -1.8)
	add_child(lamp)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.16, 0.18)
	pm.material = fm
	floor_mi.mesh = pm
	add_child(floor_mi)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _run() -> void:
	for id: String in VILLAGERS:
		if not only.is_empty() and not only.has(id):
			continue
		var d: Dictionary = Cast.CAST.get(id, {})
		if d.is_empty():
			continue
		var r: Node3D = VRig.create((d.rig as Dictionary).duplicate())
		add_child(r)
		r.scale = Vector3.ONE * VRig.SCALE
		var top: float = float(r.call("head_top")) * VRig.SCALE
		await _pair(id, r, top)
		r.queue_free()
	for id: String in DWARVES:
		if not only.is_empty() and not only.has(id):
			continue
		var dr: Node3D = DwarfRig.make(DWARVES[id])
		add_child(dr)
		await _pair(id, dr, 1.25)
		dr.queue_free()
	_sheet()
	get_tree().quit(0)


func _pair(id: String, r: Node3D, top: float) -> void:
	r.rotation.y = PI          # face +Z, toward the camera
	await _frames(4)
	cam.fov = 26.0
	cam.global_position = Vector3(0.22, top - 0.2, 0.95)
	cam.look_at(Vector3(0.0, top - 0.22, 0.0), Vector3.UP)
	await _shot("%s_face" % id)
	cam.fov = 34.0
	cam.global_position = Vector3(0.9, top * 0.6, top * 1.9)
	cam.look_at(Vector3(0.0, top * 0.5, 0.0), Vector3.UP)
	await _shot("%s_full" % id)


func _shot(nm: String) -> void:
	await _frames(6)
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://shots/npc/%s_%s.png" % [tag, nm])
	img.save_png(path)
	_shots.append(path)
	print("NPCSHOT ", path)


func _sheet() -> void:
	var faces: Array[Image] = []
	var fulls: Array[Image] = []
	for p in _shots:
		var im := Image.load_from_file(p)
		im.resize(400, 250)
		if p.ends_with("_face.png"):
			faces.append(im)
		else:
			fulls.append(im)
	var n := faces.size()
	if n == 0:
		return
	var sheet := Image.create(400 * n, 500, false, Image.FORMAT_RGBA8)
	for i in n:
		sheet.blit_rect(faces[i], Rect2i(0, 0, 400, 250), Vector2i(400 * i, 0))
		if i < fulls.size():
			sheet.blit_rect(fulls[i], Rect2i(0, 0, 400, 250), Vector2i(400 * i, 250))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/npc/%s_sheet.png" % tag))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

extends Node3D
## Studio renders of the four horse breeds (core/world/mount, horse_rig.gd) side-on and
## three-quarter, and a walk, a trot and a gallop frame, and the wanderer seated on one (the rig's ride pose), under the studios' night rig.
##   godot --path . res://zz/horse_studio.tscn -- --tag=x
## -> shots/horse/<tag>_<breed>_<view>.png, <tag>_riding.png

const HorseRig := preload("res://core/world/mount/horse_rig.gd")
const DB := preload("res://core/world/mount/horse_db.gd")

var tag := "studio"
var cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/horse"))
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
	lamp.light_energy = 3.0
	lamp.omni_range = 12.0
	lamp.position = Vector3(-2.5, 2.2, 2.5)
	add_child(lamp)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.16, 0.18)
	pm.material = fm
	floor_mi.mesh = pm
	add_child(floor_mi)
	cam = Camera3D.new()
	cam.fov = 36.0
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _run() -> void:
	for b: String in DB.ORDER:
		var d: Dictionary = DB.BREEDS[b]
		var rig := HorseRig.new()
		rig.setup(b, d)
		add_child(rig)
		rig.pose(0.0, 0.0, 0.0, 0.0)
		var s: float = float(d.seat) / 1.315
		await _shot("%s_side" % b, Vector3(3.4 * s, 1.0 * s, 0.2 * s), Vector3(0, 0.95 * s, -0.1 * s))
		await _shot("%s_34" % b, Vector3(2.0 * s, 1.3 * s, -2.4 * s), Vector3(0, 1.0 * s, -0.3 * s))
		await _shot("%s_back" % b, Vector3(-1.8 * s, 1.6 * s, 3.0 * s), Vector3(0, 1.0 * s, 0.0))
		for gait: Array in [["walk", 0.4, float(d.walk)], ["trot", 0.3, float(d.trot)], ["gallop", 0.2, float(d.gallop)]]:
			var ph: float = TAU * float(gait[1])
			for i in 30:
				rig.pose(ph, float(gait[2]), 0.0, 0.016)
			await _shot("%s_%s" % [b, gait[0]], Vector3(3.6 * s, 1.0 * s, 0.2 * s), Vector3(0, 0.95 * s, -0.1 * s))
		rig.pose(0.0, 0.0, 0.7, 0.5)
		rig.pose(0.0, 0.0, 0.7, 0.5)
		await _shot("%s_graze" % b, Vector3(3.0 * s, 1.0 * s, -1.5 * s), Vector3(0, 0.9 * s, -0.5 * s))
		rig.queue_free()
		await _frames(2)
	_sheet()
	get_tree().quit(0)


func _shot(nm: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	await _frames(8)
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shots/horse/%s_%s.png" % [tag, nm]))
	print("HORSESHOT ", nm)


func _sheet() -> void:
	pass


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

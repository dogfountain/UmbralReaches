extends Node3D
## Studio render of the wanderer (CharacterRig + DefaultLoadout): idle / walk / sprint poses from
## several angles, plus a close-up of the hood and torso. One contact sheet per run.
##   godot --path . res://zz/move_char_shot.tscn [-- --tag=before] [--night] [--casts] [--staff]
## -> shots/char_<tag>_<pose>_<view>.png and shots/char_<tag>_sheet.png
##   --casts  one row per skill pose instead (bolt flick, lance charge + throw, nova raise + slam,
##            ward, rift step, hit react, turning in place), three views each
##   --staff  close-ups of the staff head (orb, claws, runes) and the bound grip
const POSES := [["idle", 0.0], ["walk", 4.5], ["sprint", 7.5]]
## [name, speed, action, frames before the shot that the action fires (60 Hz)]
const CAST_POSES := [
	["bolt", 0.0, "bolt", 7], ["lance_charge", 0.0, "charge", 40], ["lance_throw", 0.0, "lance", 6],
	["nova_raise", 0.0, "nova", 20], ["nova_slam", 0.0, "nova", 34], ["ward", 0.0, "ward", 22],
	["step", 0.0, "step", 8], ["hurt", 0.0, "hurt", 6], ["turn", 0.0, "turn", 30],
	["tether_throw", 0.0, "tether", 18], ["tether_haul", 0.0, "tether", 40], ["well", 0.0, "well", 38],
	["familiar", 0.0, "familiar", 26],
]
const STAFF_VIEWS := [
	["orb_front", "@orb", Vector3(-0.4, 0.1, -0.75), 30.0],
	["orb_side", "@orb", Vector3(0.75, -0.05, -0.35), 30.0],
	["runes", "@shaft", Vector3(-0.15, 0.05, -0.85), 30.0],
	["grip", "@grip", Vector3(0.05, 0.05, -0.75), 32.0],
	["lantern", "@lantern", Vector3(-0.25, 0.1, -0.8), 30.0],
]
## [name, camera offset (rig faces -Z), look-at height, fov]
const VIEWS := [
	["front", Vector3(0.0, 1.0, -3.9), 0.95, 34.0],
	["q34", Vector3(-2.6, 1.2, -2.8), 0.95, 34.0],
	["side", Vector3(-3.9, 1.0, 0.0), 0.95, 34.0],
	["back", Vector3(1.4, 1.3, 3.6), 0.95, 34.0],
	["face", Vector3(-0.45, 1.62, -1.25), 1.4, 32.0],
]
const SETTLE := 70                 # physics frames of motion before the shots
var rig: CharacterRig
var cam: Camera3D
var tag := "now"
var night := false
var pose_i := 0
var view_i := 0
var f := 0
var phase := "settle"
var files: Array = []            # [path, row, col]
var casts := false
var staff := false
var poses: Array = POSES


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a == "--night":
			night = true
		elif a == "--legacy":
			DefaultLoadout.use_legacy = true
		elif a == "--casts":
			casts = true
			poses = CAST_POSES
		elif a == "--staff":
			staff = true
			poses = [["idle", 0.0]]
	Travel._busy = true                    # never write the save
	get_window().size = Vector2i(900, 1100)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if night:
		e.background_color = Color(0.03, 0.045, 0.08)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.25, 0.35, 0.6)
		e.ambient_light_energy = 0.35
	else:
		e.background_color = Color(0.3, 0.31, 0.34)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.6, 0.6, 0.65)
		e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.7, 0)
	key.light_energy = 0.7 if night else 1.4
	key.light_color = Color(0.55, 0.75, 1.0) if night else Color(1, 0.98, 0.95)
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.4, 0)
	fill.light_energy = 0.15 if night else 0.55
	add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.2, 0.22)
	fm.roughness = 0.95
	floor_mi.material_override = fm
	add_child(floor_mi)
	rig = (load("res://core/player/character_rig.gd") as GDScript).new() as CharacterRig
	rig.name = "Wanderer"
	rig.driven = true
	add_child(rig)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true


func _physics_process(delta: float) -> void:
	if pose_i >= poses.size():
		return
	var e: Array = poses[pose_i]
	var speed: float = e[1]
	if phase == "settle":
		if f == 0:
			rig.rotation.y = 0.0
		var act := String(e[2]) if e.size() > 2 else ""
		var at := SETTLE - (int(e[3]) if e.size() > 3 else 0)
		if act == "charge":
			rig.charge = clampf(float(f - at) / 30.0, 0.0, 1.0) if f >= at else 0.0
		elif act == "turn" and f >= at:
			rig.rotation.y += 2.4 * delta              # turning on the spot
		elif act != "" and f == at:
			if act == "hurt":
				rig.hurt_react(rig.global_position + Vector3(0.6, 1.0, -2.0), 25.0)
			else:
				rig.cast()
				rig.cast_pose(StringName(act))
		rig.animate(Vector3(0, 0, -speed), true, delta)
		f += 1
		if f >= SETTLE:
			phase = "shoot"
			f = 0
	# shots: hold the pose (no animate) so every view sees the same frame


func _views() -> Array:
	if staff:
		return STAFF_VIEWS
	if casts:
		return [VIEWS[0], VIEWS[1], VIEWS[2]]
	return VIEWS


func _process(_d: float) -> void:
	if pose_i >= poses.size() or phase != "shoot":
		return
	var vs := _views()
	var v: Array = vs[view_i]
	cam.fov = v[3]
	if v[1] is String:
		var focus := _focus(String(v[1]))
		cam.global_position = focus + (v[2] as Vector3)
		cam.look_at(focus)
	else:
		cam.global_position = v[1]
		cam.look_at(Vector3(0, v[2], 0))
	f += 1
	if f < 10:
		return
	var path := ProjectSettings.globalize_path("res://shots/char_%s_%s_%s.png" % [tag, poses[pose_i][0], v[0]])
	get_viewport().get_texture().get_image().save_png(path)
	files.append([path, pose_i, view_i])
	f = 0
	view_i += 1
	if view_i >= vs.size() or (not casts and not staff and pose_i > 0 and view_i >= 3):
		view_i = 0
		pose_i += 1
		phase = "settle"
	if pose_i >= poses.size():
		_sheet()
		print("CHARSHOT done ", tag)
		get_tree().quit()


func _focus(what: String) -> Vector3:
	match what:
		"@orb":
			var trail := rig.find_child("Trail", true, false) as Node3D
			if trail:
				trail.visible = false              # the motes would hide the orb this close
			return rig.muzzle()
		"@shaft":
			var h := rig.socket("hand_r")
			return h.global_position + (rig.muzzle() - h.global_position) * 0.55
		"@grip":
			return rig.socket("hand_r").global_position
		"@lantern":
			return rig.socket("hand_l").global_position + Vector3(0.0, -0.33, 0.0)
	return Vector3.ZERO


func _sheet() -> void:
	var tw := 360
	var th := 440
	var cols := 5
	var sheet := Image.create(tw * cols, th * poses.size(), false, Image.FORMAT_RGB8)
	for e: Array in files:
		var im := Image.load_from_file(e[0])
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i(int(e[2]) * tw, int(e[1]) * th))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/char_%s_sheet.png" % tag))

extends SceneTree
## Renders an animation contact sheet of the wanderer: drives CharacterRig with scripted motion.
## xvfb-run godot --path . --rendering-driver vulkan -s tools/anim_sheet.gd -- --out=/tmp/anim

var rig: CharacterRig
var cam: Camera3D
var out := "/tmp"
const DT := 1.0 / 60.0
var side_view := false
var back_view := false
var ots_view := false
var foot_close := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var root := Node3D.new()
	get_root().add_child(root)
	var we := WorldEnvironment.new()
	we.environment = load("res://world/zones/ascension/environment.tres")
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#8FA2FF")
	moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-34, 125, 0)
	moon.shadow_enabled = true
	root.add_child(moon)
	var fill := OmniLight3D.new()
	fill.light_color = Color("#A98BFF")
	fill.light_energy = 1.5
	fill.omni_range = 8.0
	fill.position = Vector3(2.5, 2.0, 2.5)
	root.add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	ground.material_override = load("res://art/materials/stone.tres")
	root.add_child(ground)
	rig = CharacterRig.new()
	root.add_child(rig)
	cam = Camera3D.new()
	cam.fov = 32.0
	root.add_child(cam)
	var layer := CanvasLayer.new()
	layer.layer = 1
	root.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = load("res://world/post/grade_material.tres")
	layer.add_child(rect)
	await process_frame
	cam.current = true
	await _run()
	quit()

func _shot(tag: String) -> void:
	await process_frame
	await process_frame
	get_root().get_texture().get_image().save_png(out.path_join(tag + ".png"))

func _aim() -> void:
	var look := rig.position + Vector3(0, 0.95, 0)
	var off := Vector3(3.0, 1.2, -3.4)
	cam.fov = 32.0
	if side_view:
		off = Vector3(4.4, 1.1, -0.6)
	if back_view:
		off = Vector3(2.2, 1.2, 3.8)
	if ots_view:
		# Match player OTS so the plant reads like the in-game shot.
		off = Vector3(1.15, 1.35, 2.55)
		look = rig.position + Vector3(0.15, 0.85, -0.35)
		cam.fov = 55.0
	if foot_close:
		off = Vector3(1.55, 0.55, -0.15)
		look = rig.position + Vector3(0.0, 0.22, -0.35)
		cam.fov = 42.0
	cam.look_at_from_position(rig.position + off, look)

func _drive(vel: Vector3, on_floor: bool, seconds: float) -> void:
	var n := int(seconds / DT)
	for i in n:
		rig.position += Vector3(vel.x, 0, vel.z) * DT
		rig.animate(vel, on_floor, DT)
	_aim()

## Advance at full walk/sprint until the requested foot plant peaks (1 = left, -1 = right).
func _drive_to_plant(vel: Vector3, side: float, max_s: float = 0.55) -> void:
	var n := int(max_s / DT)
	var prev := -2.0
	for i in n:
		rig.position += Vector3(vel.x, 0, vel.z) * DT
		rig.animate(vel, true, DT)
		var score := float(sin(rig.get("_phase"))) * side
		# Stop on the frame we tip over the peak so the lead boot is fully extended.
		if prev > 0.85 and score < prev:
			break
		prev = score
	_aim()

func _run() -> void:
	rig.rotation.y = 0.0   # facing -Z; travel along -Z
	await _drive(Vector3.ZERO, true, 1.5)
	await _shot("a_idle")
	var walk := Vector3(0, 0, -4.5)
	# Warm into full stride at walk speed (not a crawl).
	await _drive(walk, true, 1.2)

	# Foot close-ups at left/right plant peaks — this is the poke the owner annotated.
	foot_close = true
	side_view = false
	ots_view = false
	back_view = false
	await _drive_to_plant(walk, 1.0)
	await _shot("b_plant_l_close")
	await _drive_to_plant(walk, -1.0)
	await _shot("b_plant_r_close")

	# Side full-body at the same peaks.
	foot_close = false
	side_view = true
	await _drive_to_plant(walk, 1.0)
	await _shot("b_plant_l_side")
	await _drive_to_plant(walk, -1.0)
	await _shot("b_plant_r_side")

	# OTS like the game camera.
	side_view = false
	ots_view = true
	await _drive_to_plant(walk, 1.0)
	await _shot("b_plant_l_ots")
	await _drive_to_plant(walk, -1.0)
	await _shot("b_plant_r_ots")

	ots_view = false
	side_view = true
	var sprint_s := Vector3(0, 0, -7.5)
	await _drive(sprint_s, true, 0.9)
	await _drive_to_plant(sprint_s, 1.0)
	await _shot("c_sprint_plant_l")
	await _drive_to_plant(sprint_s, -1.0)
	await _shot("c_sprint_plant_r")

	side_view = false
	ots_view = true
	await _drive_to_plant(sprint_s, 1.0)
	await _shot("c_sprint_ots_l")
	await _drive_to_plant(sprint_s, -1.0)
	await _shot("c_sprint_ots_r")

	ots_view = false
	side_view = true
	await _drive(Vector3.ZERO, true, 0.18)
	await _shot("d_stop_overshoot")
	await _drive(Vector3(0, 4.5, -3.0), false, 0.25)
	await _shot("e_jump")
	await _drive(Vector3(0, -6.0, -3.0), false, 0.35)
	await _shot("f_fall")
	await _drive(Vector3.ZERO, true, 0.08)
	await _shot("g_land")
	await _drive(Vector3.ZERO, true, 1.0)
	rig.cast()
	await _drive(Vector3.ZERO, true, 0.45)
	await _shot("h_cast")

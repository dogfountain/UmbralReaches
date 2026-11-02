extends SceneTree
## Fast walk debug reel. Default side+foot, low-res JPEG, one wait/frame.
## godot --path . --rendering-driver vulkan -s tools/walk_video.gd -- --out=/tmp/walkvid
## --quick = foot only (18f). --all adds ots+sprint.

var rig: CharacterRig
var cam: Camera3D
var out := "/tmp/walkvid"
var quick := false
var all_shots := false
const DT := 1.0 / 30.0
const WALK := Vector3(0, 0, -4.5)
const SPRINT := Vector3(0, 0, -7.5)

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--quick":
			quick = true
		elif a == "--all":
			all_shots = true
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(640, 360))
	var root := Node3D.new()
	get_root().add_child(root)
	var we := WorldEnvironment.new()
	we.environment = load("res://world/zones/ascension/environment.tres")
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#8FA2FF")
	moon.light_energy = 0.85
	moon.rotation_degrees = Vector3(-34, 125, 0)
	moon.shadow_enabled = false
	root.add_child(moon)
	var fill := OmniLight3D.new()
	fill.light_color = Color("#A98BFF")
	fill.light_energy = 1.4
	fill.omni_range = 9.0
	fill.position = Vector3(2.5, 2.0, 2.0)
	root.add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	ground.material_override = load("res://art/materials/stone.tres")
	root.add_child(ground)
	var stripe := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.02, 20.0)
	stripe.mesh = box
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.2, 0.05)
	sm.emission_enabled = true
	sm.emission = Color(0.8, 0.35, 0.05)
	sm.emission_energy_multiplier = 0.55
	stripe.material_override = sm
	stripe.position = Vector3(0.85, 0.01, 0.0)
	root.add_child(stripe)
	rig = CharacterRig.new()
	# Skip rim light for debug speed.
	rig.rim_light = false
	root.add_child(rig)
	cam = Camera3D.new()
	root.add_child(cam)
	await process_frame
	cam.current = true
	var t0 := Time.get_ticks_msec()
	await _reel(stripe)
	print("walk_video done in ", Time.get_ticks_msec() - t0, "ms -> ", out)
	quit()

func _aim(mode: String) -> void:
	match mode:
		"side":
			cam.fov = 36.0
			cam.look_at_from_position(rig.position + Vector3(4.0, 1.0, -0.3), rig.position + Vector3(0, 0.95, 0))
		"foot":
			cam.fov = 42.0
			cam.look_at_from_position(rig.position + Vector3(1.55, 0.4, -0.08), rig.position + Vector3(0.04, 0.14, -0.32))
		"ots":
			cam.fov = 55.0
			cam.look_at_from_position(rig.position + Vector3(1.05, 1.3, 2.5), rig.position + Vector3(0.12, 0.82, -0.45))
		_:
			cam.fov = 36.0
			cam.look_at_from_position(rig.position + Vector3(4.0, 1.0, -0.4), rig.position + Vector3(0, 0.95, 0))

func _shot(path: String) -> void:
	await process_frame
	# JPEG is much cheaper than PNG for debug dumps.
	get_root().get_texture().get_image().save_jpg(path, 0.72)

func _inplace(vel: Vector3, mode: String, tag: String, frames: int, stripe: Node3D) -> void:
	rig.position = Vector3.ZERO
	_aim(mode)
	for i in 6:
		rig.animate(vel, true, DT)
		stripe.position.z = fmod(stripe.position.z - vel.z * DT, 8.0)
	for i in frames:
		stripe.position.z = fmod(stripe.position.z - vel.z * DT, 8.0)
		rig.animate(vel, true, DT)
		_aim(mode)
		await _shot(out.path_join("%s_%04d.jpg" % [tag, i]))

func _reel(stripe: Node3D) -> void:
	rig.rotation.y = 0.0
	if quick:
		await _inplace(WALK, "foot", "foot", 18, stripe)
		return
	# 24f @ 30fps ≈ 0.8s each — enough to see a plant without the 30s wait.
	await _inplace(WALK, "side", "side", 24, stripe)
	await _inplace(WALK, "foot", "foot", 24, stripe)
	if all_shots:
		await _inplace(WALK, "ots", "ots", 20, stripe)
		await _inplace(SPRINT, "side", "sprint", 20, stripe)

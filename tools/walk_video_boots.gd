extends SceneTree
## Walk reel with neon boots so poke is measurable. --out=/tmp/walkvid_boots

var rig: CharacterRig
var cam: Camera3D
var out := "/tmp/walkvid_boots"
const DT := 1.0 / 30.0
const WALK := Vector3(0, 0, -4.5)

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var root := Node3D.new()
	get_root().add_child(root)
	var we := WorldEnvironment.new()
	we.environment = load("res://world/zones/ascension/environment.tres")
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-34, 125, 0)
	root.add_child(moon)
	var fill := OmniLight3D.new()
	fill.light_energy = 1.5
	fill.position = Vector3(2.5, 2.0, 2.5)
	root.add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	ground.material_override = load("res://art/materials/stone.tres")
	root.add_child(ground)
	rig = CharacterRig.new()
	root.add_child(rig)
	cam = Camera3D.new()
	root.add_child(cam)
	await process_frame
	_paint_boots()
	cam.current = true
	for i in 40:
		rig.position += Vector3(0, 0, WALK.z) * DT
		rig.animate(WALK, true, DT)
	for i in 90:
		rig.position += Vector3(0, 0, WALK.z) * DT
		rig.animate(WALK, true, DT)
		var off := Vector3(1.7, 0.48, -0.05)
		var look := rig.position + Vector3(0.05, 0.18, -0.4)
		cam.fov = 40.0
		cam.look_at_from_position(rig.position + off, look)
		await process_frame
		await process_frame
		get_root().get_texture().get_image().save_png(out.path_join("f_%04d.png" % i))
	print("done")
	quit()

func _paint_boots() -> void:
	for key in ["boot_l", "boot_r"]:
		var boot_root: Node = rig.get("_equipped").get(key)
		if boot_root == null:
			continue
		var col := Color(0, 1, 0) if key.ends_with("l") else Color(1, 0, 0)
		for node in boot_root.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.emission_enabled = true
			mat.emission = col
			mat.emission_energy_multiplier = 12.0
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = mat

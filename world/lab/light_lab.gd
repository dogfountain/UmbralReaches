extends Node3D
## Primitive light lab. Tune bloom, shafts, probes and shadows without art.
## godot --path . res://world/lab/light_lab.tscn -- --no-ssr --no-dof --no-gi


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--no-ssr" in args:
		Settings.ssr_enabled = false
	if "--no-dof" in args:
		Settings.dof_enabled = false
	var no_gi := "--no-gi" in args

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#060814")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#1A2040")
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.5
	env.glow_enabled = true
	env.glow_intensity = 1.05
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 0.94
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.04
	env.volumetric_fog_albedo = Color("#0A1024")
	env.volumetric_fog_anisotropy = 0.68
	env.volumetric_fog_length = 24.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("#8FA2FF")
	moon.light_energy = 0.45
	moon.rotation_degrees = Vector3(-38.0, 130.0, 0.0)
	add_child(moon)

	var floor := CSGBox3D.new()
	floor.size = Vector3(16.0, 0.3, 16.0)
	floor.position = Vector3(0.0, -0.15, 0.0)
	add_child(floor)

	var wall := CSGCombiner3D.new()
	wall.name = "LancetWall"
	wall.position = Vector3(0.0, 2.4, -4.0)
	var slab := CSGBox3D.new()
	slab.size = Vector3(6.0, 5.0, 0.5)
	wall.add_child(slab)
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(1.1, 3.2, 0.8)
	hole.position = Vector3(0.0, 0.2, 0.0)
	wall.add_child(hole)
	var arch := CSGCylinder3D.new()
	arch.operation = CSGShape3D.OPERATION_SUBTRACTION
	arch.radius = 0.55
	arch.height = 0.8
	arch.sides = 12
	arch.position = Vector3(0.0, 1.8, 0.0)
	arch.rotation = Vector3(0.0, 0.0, PI * 0.5)
	wall.add_child(arch)
	add_child(wall)

	var spot := SpotLight3D.new()
	spot.name = "HeroSpot"
	spot.position = Vector3(0.0, 2.6, -5.4)
	spot.rotation_degrees = Vector3(8.0, 0.0, 0.0)
	spot.light_color = Color(0.32, 0.92, 0.86)
	spot.light_energy = 5.6
	spot.spot_range = 16.0
	spot.spot_angle = 28.0
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 2.5
	spot.set_meta("hero", true)
	spot.set_meta("light_class", "hero")
	spot.light_projector = _lab_gobo()
	add_child(spot)

	var fill := OmniLight3D.new()
	fill.name = "HeroFill"
	fill.position = Vector3(0.0, 2.5, -3.4)
	fill.light_color = Color(0.32, 0.92, 0.86)
	fill.light_energy = 0.8
	fill.omni_range = 5.0
	fill.set_meta("hero", true)
	fill.set_meta("light_class", "hero_fill")
	add_child(fill)

	var shaft := FogVolume.new()
	shaft.name = "ShaftMist"
	shaft.size = Vector3(3.5, 4.0, 8.0)
	shaft.position = Vector3(0.0, 2.0, -0.4)
	var fmat := FogMaterial.new()
	fmat.density = 0.12
	fmat.albedo = Color(0.28, 0.82, 0.78)
	fmat.edge_fade = 0.4
	shaft.material = fmat
	add_child(shaft)

	var brazier := OmniLight3D.new()
	brazier.name = "Brazier"
	brazier.position = Vector3(3.4, 1.4, 2.2)
	brazier.light_color = Color("#FFB347")
	brazier.light_energy = 3.2
	brazier.omni_range = 11.0
	brazier.shadow_enabled = true
	brazier.set_meta("light_class", "beacon")
	add_child(brazier)
	var bowl := CSGCylinder3D.new()
	bowl.radius = 0.35
	bowl.height = 1.1
	bowl.position = Vector3(3.4, 0.55, 2.2)
	add_child(bowl)

	_sphere(Vector3(-2.2, 0.7, 1.6), 0.1, false)
	_sphere(Vector3(-0.6, 0.7, 1.6), 0.4, false)
	_sphere(Vector3(1.0, 0.7, 1.6), 0.8, false)
	_sphere(Vector3(2.4, 0.7, 1.6), 0.2, true)

	var grey := CSGBox3D.new()
	grey.size = Vector3(1.2, 0.8, 0.04)
	grey.position = Vector3(-3.4, 1.1, 2.8)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.18, 0.18, 0.18)
	gmat.roughness = 0.7
	grey.material = gmat
	add_child(grey)

	if not no_gi:
		var probe := ReflectionProbe.new()
		probe.position = Vector3(0.0, 2.0, 0.0)
		probe.size = Vector3(14.0, 6.0, 14.0)
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.box_projection = true
		probe.interior = true
		add_child(probe)

	_cam("WindowFacing", Vector3(0.0, 1.6, 7.5), Vector3(0.0, 2.2, -4.0), true)
	_cam("ShaftInFog", Vector3(3.8, 1.4, 1.2), Vector3(0.0, 2.2, -3.2), false)
	_cam("Reflections", Vector3(-1.2, 1.1, 4.2), Vector3(0.2, 0.7, 1.6), false)

	var cam := get_node("WindowFacing") as Camera3D
	load("res://core/world/atmosphere.gd").apply_quality(env, cam)
	load("res://core/world/light_policy.gd").apply_all(self, moon)


func _sphere(pos: Vector3, rough: float, metal: bool) -> void:
	var s := CSGSphere3D.new()
	s.radius = 0.42
	s.radial_segments = 16
	s.rings = 10
	s.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.64, 0.7)
	mat.roughness = rough
	mat.metallic = 0.85 if metal else 0.04
	s.material = mat
	add_child(s)


func _cam(id: String, from: Vector3, look: Vector3, current: bool) -> void:
	var cam := Camera3D.new()
	cam.name = id
	cam.fov = 54.0
	cam.current = current
	add_child(cam)
	cam.look_at_from_position(from, look)


func _lab_gobo() -> Texture2D:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	for y in 128:
		for x in 64:
			var u := (float(x) + 0.5) / 64.0
			var v := (float(y) + 0.5) / 128.0
			var open := absf(u - 0.5) < 0.28 and v > 0.12 and v < 0.88
			var bar := absf(u - 0.5) < 0.03
			img.set_pixel(x, y, Color.WHITE if open and not bar else Color.BLACK)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

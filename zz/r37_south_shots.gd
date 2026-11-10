extends Node3D
## Studio renders of the South pass's Blender kits (art/models/r37_south_*.glb), night-lit like the
## zone (cold moonlight, the zone's glow budget): the wall kit in a row, a gatehouse, the Grandmother
## Oak outside and up its stair, the Well's pieces, the hut and fold.
##   godot --path . res://zz/r37_south_shots.tscn -- --what=wall,gate,oak,oak_in,well,hut --out=/some/dir
## Output: <out>/south_<what>_<view>.png (default shots/)

const Kit := preload("res://core/world/realm/south_marches_kit.gd")

var cam: Camera3D
var out_dir := "res://shots"
var subject: Node3D


func _ready() -> void:
	var what := "wall,gate,oak,oak_in,well,hut"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--what="):
			what = a.trim_prefix("--what=")
		elif a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_stage()
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	_run(what.split(","))


func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.045, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#2A3050")
	e.ambient_light_energy = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.5
	e.glow_enabled = true
	e.glow_intensity = 0.62
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.15
	for l in 7:
		e.set_glow_level(l, l <= 1)
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(-0.7, 0.8, 0)
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 1.5
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 200.0
	add_child(moon)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.62, 0.32)
	warm.light_energy = 2.0
	warm.omni_range = 18.0
	warm.position = Vector3(-4.0, 2.0, 12.0)
	add_child(warm)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.16, 0.18, 0.17)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = -0.02
	add_child(ground)


func _put(path: String, part: String, at: Vector3, yaw := 0.0, scale := Vector3.ONE) -> void:
	var m := Kit.mesh(path, part)
	if m == null:
		print("SOUTH_SHOT missing ", part)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	subject.add_child(mi)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), at)
	var tris := 0
	for s in m.get_surface_count():
		tris += int((m.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
	print("SOUTH_SHOT %s tris=%d" % [part, tris])


func _run(list: PackedStringArray) -> void:
	for nm in list:
		subject = Node3D.new()
		add_child(subject)
		var views: Array = []
		match nm:
			"wall":
				var x := -34.0
				for p: String in ["WallSeg_A", "WallSeg_B", "WallSeg_C"]:
					_put(Kit.WALL, p, Vector3(x, 0, 0))
					x += 12.5
				_put(Kit.WALL, "Tower", Vector3(x + 2.0, 0, 0))
				_put(Kit.WALL, "TowerRuin", Vector3(x + 14.0, 0, 0))
				views = [[Vector3(-4, 9, 46), Vector3(-2, 4, 0)], [Vector3(-60, 6, 30), Vector3(-6, 4, 0)]]
			"gate":
				_put(Kit.WALL, "Gatehouse", Vector3.ZERO)
				_put(Kit.WALL, "WallSeg_A", Vector3(-22.0, 0, 0))
				_put(Kit.WALL, "BreachStub", Vector3(22.0, 0, 0))
				_put(Kit.WALL, "Rubble", Vector3(31.0, 0, 0))
				views = [[Vector3(6, 4, 30), Vector3(0, 6, 0)], [Vector3(-22, 7, 24), Vector3(0, 5, 0)], [Vector3(0, 2.2, 12), Vector3(0, 3, -8)]]
			"oak":
				for p: String in ["Trunk", "Roots", "Limbs", "Crown", "Stair"]:
					_put(Kit.OAK, p, Vector3.ZERO)
				views = [[Vector3(18, 18, 96), Vector3(0, 17, 0)], [Vector3(-60, 14, -50), Vector3(0, 16, 0)], [Vector3(2, 2.0, -14), Vector3(0, 6, 0)]]
			"oak_in":
				for p: String in ["Trunk", "Roots", "Limbs", "Crown", "Stair"]:
					_put(Kit.OAK, p, Vector3.ZERO)
				views = [[Vector3(0.6, 1.6, -4.2), Vector3(-0.5, 9, 2.2)], [Vector3(-0.4, 18, 0.4), Vector3(0.5, 30, 1.5)]]
			"well":
				var x2 := -34.0
				for p: String in ["LedgeSlab", "LedgeSlabOpen", "LedgeLanding", "Corbel", "Pier", "DescentGate", "CaveMouth", "Spillway", "EchoStone", "RimPost", "Rubble"]:
					_put(Kit.WELL, p, Vector3(x2, 0, 0))
					x2 += 9.0
				views = [[Vector3(0, 12, 46), Vector3(0, 2, 0)]]
			"hut":
				_put(Kit.HUT, "Hut", Vector3(-8, 0, 0))
				var xx := 0.0
				for p: String in ["FoldWall", "FoldWallB", "Hurdle", "Trough", "Rack", "BellPost", "Bench"]:
					_put(Kit.HUT, p, Vector3(xx, 0, 0))
					xx += 4.6
				views = [[Vector3(8, 6, 22), Vector3(6, 1.5, 0)], [Vector3(-16, 5, 12), Vector3(-8, 2, 0)]]
		for vi in views.size():
			var v: Array = views[vi]
			cam.global_position = v[0]
			cam.look_at(v[1])
			for _f in (24 if vi == 0 else 8):
				await RenderingServer.frame_post_draw
			var path := "%s/south_%s_%d.png" % [out_dir, nm, vi]
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
			print("SOUTH_SHOT saved ", path)
		subject.queue_free()
		await RenderingServer.frame_post_draw
	print("SOUTH_SHOT done")
	get_tree().quit()

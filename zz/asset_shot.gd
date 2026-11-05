extends Node3D
## Studio renders for the assets module (RockKit + upgraded props), night-lit like the zone
## (cold moonlight, a warm lantern fill, the zone's glow budget), framed from each subject's AABB.
##   godot --path . res://zz/asset_shot.tscn -- --what=rockkit        RockKit gallery (+ tri counts)
##   godot --path . res://zz/asset_shot.tscn -- --what=menhir         before (left) | after (right)
##   godot --path . res://zz/asset_shot.tscn -- --what=all            every prop + the gallery
##   add --studio for neutral grey light. Output: shots/asset_<what>_<view>.png
## Props: menhir cairn rune_slab twisted_root fallen_branch lantern stone_frame mirror_frame rock_a rock_b
## Sheets: godot --headless -s zz/tile.gd -- shots/asset_sheet.png 2 900 shots/asset_*_0.png

const Assets := "res://core/world/realm/realm_assets.gd"
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const PROPS := ["menhir", "cairn", "rune_slab", "twisted_root", "fallen_branch", "lantern",
	"stone_frame", "mirror_frame", "rock_a", "rock_b"]

var queue: Array = []
var subject: Node3D
var cam: Camera3D
var views: Array = []
var nm := ""
var studio := false


func _ready() -> void:
	var what := "rockkit"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--what="):
			what = a.trim_prefix("--what=")
		elif a == "--studio":
			studio = true
	if what == "all":
		queue = ["rockkit", "rockkit_close"] + PROPS
	else:
		queue = what.split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	_stage()
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	_run()


func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 0.91
	e.tonemap_white = 6.5
	e.glow_enabled = true
	e.glow_intensity = 0.62
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.15
	for l in 7:
		e.set_glow_level(l, l <= 1)
	if studio:
		e.background_color = Color(0.32, 0.33, 0.36)
		e.ambient_light_color = Color(0.55, 0.55, 0.6)
		e.ambient_light_energy = 0.6
	else:
		e.background_color = Color(0.035, 0.045, 0.08)
		e.ambient_light_color = Color("#1A2040")
		e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(-0.62, 0.75, 0)
	moon.light_color = Color(1, 1, 1) if studio else Color(0.62, 0.72, 1.0)
	moon.light_energy = 1.3 if studio else 1.15
	moon.shadow_enabled = true
	add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.4, 0)
	fill.light_energy = 0.45 if studio else 0.18
	fill.light_color = Color(0.7, 0.75, 0.9)
	add_child(fill)
	if not studio:
		var warm := OmniLight3D.new()
		warm.name = "Warm"
		warm.light_color = Color(1.0, 0.62, 0.32)
		warm.light_energy = 1.4
		warm.omni_range = 9.0
		warm.position = Vector3(-3.0, 1.6, 3.0)
		add_child(warm)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.22, 0.26) if studio else Color(0.1, 0.12, 0.13)
	gm.albedo_texture = load("res://art/textures/ground_albedo.png")
	gm.uv1_triplanar = true
	gm.uv1_world_triplanar = true
	gm.uv1_scale = Vector3.ONE * 0.25
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)


## One subject at a time; waits on frame_post_draw (frames actually drawn, not process ticks:
## a hidden or throttled window keeps processing without drawing, and the shots went stale).
func _run() -> void:
	while not queue.is_empty():
		nm = String(queue.pop_front())
		subject = Node3D.new()
		subject.name = "Subject_" + nm
		add_child(subject)
		if nm.begins_with("rockkit"):
			_gallery(nm == "rockkit_close")
		else:
			_before_after(nm)
		var bb := _bounds(subject)
		var c := bb.get_center()
		var r := maxf(bb.size.length() * 0.5, 0.3)
		var dist := r / tan(deg_to_rad(cam.fov * 0.5)) * 1.02
		if nm == "rockkit_close":
			dist *= 0.55
		views = [
			[c + Vector3(0.25, 0.32, 1.0).normalized() * dist, c],
			[c + Vector3(-0.55, 0.55, 0.75).normalized() * dist * (0.7 if nm.begins_with("rockkit") else 0.9), c],
		]
		for vi_ in views.size():
			var v: Array = views[vi_]
			cam.global_position = v[0]
			cam.look_at(v[1])
			for _f in (24 if vi_ == 0 else 6):
				await RenderingServer.frame_post_draw
			var path := "res://shots/asset_%s_%d.png" % [nm, vi_]
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("ASSET_SHOT saved ", nm)
		subject.queue_free()
		subject = null
		await RenderingServer.frame_post_draw
	print("ASSET_SHOT done")
	get_tree().quit()


## Old GLB on the left, the same GLB after RealmAssets.upgrade() on the right.
func _before_after(prop: String) -> void:
	var path := "res://art/models/%s.glb" % prop
	var before := (load(path) as PackedScene).instantiate() as Node3D
	var after := (load(path) as PackedScene).instantiate() as Node3D
	subject.add_child(before)
	subject.add_child(after)
	# the game paints these through material_override; mimic it so "before" is honest
	_game_paint(before, prop)
	_game_paint(after, prop)
	var s := load(Assets) as GDScript
	var ok := false
	if s != null and s.can_instantiate():
		ok = bool(s.call("upgrade", after))
	var bb := _bounds(before)
	var off := maxf(bb.size.x, bb.size.z) * 0.62 + 0.25
	before.position.x = -off
	after.position.x = off
	print("ASSET %s upgraded=%s before_tris=%d after_tris=%d" % [prop, ok, _tris(before), _tris(after)])


func _game_paint(model: Node, prop: String) -> void:
	match prop:
		"menhir", "stone_frame":
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = load("res://art/materials/stone.tres")


func _gallery(close: bool) -> void:
	var x := 0.0
	var row := func(meshes: Array, z: float) -> void:
		var xx := 0.0
		var total := 0.0
		for m: Mesh in meshes:
			total += m.get_aabb().size.x + 0.8
		xx = -total * 0.5
		for m: Mesh in meshes:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			subject.add_child(mi)
			var w := m.get_aabb().size.x
			mi.position = Vector3(xx + w * 0.5 - m.get_aabb().get_center().x, 0.0, z)
			xx += w + 0.8
			print("ROCKKIT %s tris=%d aabb=%s" % [m.resource_name, RockKit.tris(m), m.get_aabb().size])
	if close:
		row.call([RockKit.boulder(1, Vector3(1.6, 1.1, 1.4), "granite"), RockKit.boulder(2, Vector3(1.8, 1.2, 1.5), "mossy"),
			RockKit.boulder(3, Vector3(1.2, 1.5, 1.2), "basalt"), RockKit.boulder(4, Vector3(1.6, 1.0, 1.4), "ash")], 0.0)
		return
	row.call([RockKit.boulder(1, Vector3(2.4, 1.6, 2.0), "granite"), RockKit.boulder(2, Vector3(2.6, 1.7, 2.2), "mossy"),
		RockKit.boulder(3, Vector3(1.6, 2.2, 1.6), "basalt"), RockKit.boulder(4, Vector3(2.2, 1.4, 1.9), "ash"),
		RockKit.boulder(5, Vector3(0.7, 0.45, 0.6), "granite"), RockKit.boulder(6, Vector3(4.0, 2.6, 3.2), "mossy")], 4.0)
	row.call([RockKit.cliff(1, Vector3(8.0, 6.0, 3.0), "granite"), RockKit.cliff(2, Vector3(7.0, 5.0, 3.0), "mossy"),
		RockKit.cliff(3, Vector3(6.0, 6.0, 2.5), "basalt"), RockKit.cliff(4, Vector3(7.0, 4.0, 3.0), "ash")], -4.0)
	row.call([RockKit.basalt_columns(1, 3.0, 5.0), RockKit.basalt_columns(2, 1.6, 2.5)], -12.0)
	x = 0.0


static func _bounds(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for gi in n.find_children("*", "MeshInstance3D", true, false):
		var mi := gi as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _tris(n: Node) -> int:
	var c := 0
	for gi in n.find_children("*", "MeshInstance3D", true, false):
		var mi := gi as MeshInstance3D
		if mi.is_visible_in_tree() and mi.mesh != null:
			c += RockKit.tris(mi.mesh)
	return c

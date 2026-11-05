extends Node
## Look check for performance work: the real player camera at Luke's settings (Cinematic, fov 90,
## 3D capped at 960 rows, grade on, HUD off) at the zz/look_shots views plus the hub, saved as
## shots/perf_look_<view>_<tag>.png and a contact sheet. Settings live in memory only and Travel
## saves are blocked (Travel._busy), so neither settings.cfg nor the save is written.
##   godot --path . res://zz/perf_look.tscn -- --tag=before
##   godot --path . res://zz/perf_look.tscn -- --tag=after --compare=before
## Options:
##   --tag=x            file suffix (default "now")
##   --compare=y        after each shot, diff against perf_look_<view>_<y>.png: mean abs difference
##                      (0-255), share of pixels off by more than 6 and 16 levels, and a x8 diff image
##   --only=a,b         only these views
##   --off=ssr,ssao,blur,glow,fog,blend   switch features off (blend: moon shadow split blending) in memory (what does it add to the look?)
## Pass --life-weather=clear too: weather fronts change fog between runs.
## Holds each view SETTLE frames; the wanderer stands (re-placed only if he drifts).
const VIEWS := [
	# zz/look_shots views
	["spawn", Vector3(0.0, 0.2, 24.0), 0.0, -0.06],
	["meadow", Vector3(-20.0, 0.3, 40.0), 2.4, -0.04],
	["thornwood", Vector3(-80.0, 3.0, 10.0), 0.4, -0.02],
	["henge", Vector3(-62.0, 8.0, -12.0), 0.9, -0.05],
	["fen", Vector3(62.0, 0.0, 6.0), -0.6, -0.06],
	["crossing", Vector3(0.0, 0.8, -10.0), 0.0, 0.05],
	["tavern", Vector3(12.0, -0.5, 27.0), -0.9, -0.08],
	["summit", Vector3(0.0, 27.9, -92.0), 0.0, -0.05],
	# the hub (Hearthward): y NAN = stand on the ground there
	["hub_brazier", Vector3(0.0, NAN, 44.0), 0.0, -0.08],
	["hub_village", Vector3(0.0, NAN, 36.0), PI, -0.06],
	["hub_west", Vector3(0.0, NAN, 30.0), PI * 0.5, -0.08],
	["hub_north", Vector3(0.0, NAN, 40.0), 0.0, -0.02],
	["hub_meadow", Vector3(8.0, NAN, 48.0), -2.2 + PI, -0.08],
	["hub_tavern_door", Vector3(2.0, NAN, 22.0), -1.2, -0.06],
]
const SETTLE := 45
var p: Player
var main: Node
var i := -1
var wait := 0
var tag := "_now"
var cmp := ""
var only: PackedStringArray = []
var off: PackedStringArray = []
var views: Array = []
var files: Array[String] = []
var started := 0
var _held: Array[Resource] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true                                   # never write the real save
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = "_" + a.trim_prefix("--tag=")
		elif a.begins_with("--compare="):
			cmp = "_" + a.trim_prefix("--compare=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
		elif a.begins_with("--off="):
			off = a.trim_prefix("--off=").split(",")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shader="):              # --shader=res://a.gdshader=/abs/b.gdshader (memory only)
			var parts := a.trim_prefix("--shader=").split("=")
			var sh := load(parts[0]) as Shader
			var code := FileAccess.get_file_as_string(parts[1])
			if sh and code != "":
				sh.code = code
				_held.append(sh)
	views = VIEWS.duplicate(true).filter(func(v: Array) -> bool: return only.is_empty() or String(v[0]) in only)
	# Luke's settings, in memory only
	Settings.set_preset_fields(2)
	Settings.fov = 90.0
	Settings.render_scale = 0.0
	Settings.fullscreen = false
	Settings.vsync = true
	Settings.fps_limit = 0
	if "ssr" in off:
		Settings.ssr_enabled = false
	if "ssao" in off:
		Settings.ssao_enabled = false
	if "glow" in off:
		Settings.glow_enabled = false
	if "fog" in off:
		Settings.fog_enabled = false
	if "blur" in off:
		Settings.motion_blur = 0.0
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p:
			Settings.changed.emit()
			get_window().size = Vector2i(1600, 1000)        # the zone applies Luke's window size
		return
	if Realm.enabled() and not main.has_meta("realm_done"):
		return
	if started == 0 and "blend" in off:
		var moon := main.get_node_or_null("Moon") as DirectionalLight3D
		if moon:
			moon.directional_shadow_blend_splits = false
	started += 1
	if started < 200:                                     # post-build pass, streaming, shader compiles
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		if n is Node3D:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			(n as Node3D).visible = false
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	if i >= 0 and i < views.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := ProjectSettings.globalize_path("res://shots/perf_look_%s%s.png" % [views[i][0], tag])
		var img := get_viewport().get_texture().get_image()
		img.save_png(path)
		files.append(path)
		if cmp != "":
			_compare(String(views[i][0]), img)
	i += 1
	if i >= views.size():
		_sheet()
		print("PERF_LOOK done")
		OS.kill(OS.get_process_id())
		return
	_hold(true)
	p.set_view(float(views[i][2]), float(views[i][3]))
	wait = SETTLE


func _hold(force := false) -> void:
	var at: Vector3 = views[i][1]
	if is_nan(at.y):
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.1
		views[i][1] = at
	if force or p.global_position.distance_to(at) > 0.3:
		p.global_position = at
		p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO


func _compare(view: String, img: Image) -> void:
	var ref_path := ProjectSettings.globalize_path("res://shots/perf_look_%s%s.png" % [view, cmp])
	var ref := Image.load_from_file(ref_path)
	if ref == null or ref.get_size() != img.get_size():
		print("PERF_LOOK %-16s no reference %s" % [view, ref_path.get_file()])
		return
	img.convert(Image.FORMAT_RGB8)
	ref.convert(Image.FORMAT_RGB8)
	var a := img.get_data()
	var b := ref.get_data()
	var n := a.size() / 3
	var sum := 0
	var la := 0.0
	var lb := 0.0
	var over6 := 0
	var over16 := 0
	var diff := PackedByteArray()
	diff.resize(a.size())
	for k in n:
		var o := k * 3
		var d := maxi(absi(a[o] - b[o]), maxi(absi(a[o + 1] - b[o + 1]), absi(a[o + 2] - b[o + 2])))
		sum += absi(a[o] - b[o]) + absi(a[o + 1] - b[o + 1]) + absi(a[o + 2] - b[o + 2])
		la += 0.299 * a[o] + 0.587 * a[o + 1] + 0.114 * a[o + 2]
		lb += 0.299 * b[o] + 0.587 * b[o + 1] + 0.114 * b[o + 2]
		if d > 6:
			over6 += 1
		if d > 16:
			over16 += 1
		var v := mini(255, d * 8)
		diff[o] = v
		diff[o + 1] = v
		diff[o + 2] = v
	print("PERF_LOOK %-16s vs %s: mean abs %.2f  >6: %.2f%%  >16: %.2f%%  luma %.2f -> %.2f" % [view, cmp.trim_prefix("_"),
		float(sum) / float(n * 3), 100.0 * over6 / n, 100.0 * over16 / n, lb / n, la / n])
	var dimg := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8, diff)
	dimg.save_png(ProjectSettings.globalize_path("res://shots/perf_look_%s%s_diff.png" % [view, tag]))


func _sheet() -> void:
	var tw := 400
	var th := 250
	var cols := 4
	var rows := ceili(files.size() / float(cols))
	var sheet := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for k in files.size():
		var im := Image.load_from_file(files[k])
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((k % cols) * tw, (k / cols) * th))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/perf_look_sheet%s.png" % tag))

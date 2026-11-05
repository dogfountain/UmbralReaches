extends Node
## Lines probe (r29 critique E): the "weird shadow lines" from the real player camera at Luke's
## output (1920x1080 window, 3D capped at 960 rows, Cinematic, fov 90), stills plus a moving-camera
## filmstrip and a flicker number per view. Settings live in memory only; the save is held.
##   godot --path . res://zz/perf_lines.tscn [-- options]
##   --tag=x                     files shots/critE_lines_<view>_<x>.png (+ _strip)
##   --preset=2                  quality preset fields (default 2 Cinematic)
##   --set=k:v,...               Settings fields after the preset (memory only)
##   --view=name,x,y,z,yaw,pitch only these views (repeatable; y = nan stands on the ground)
##   --moon=k:v,...              DirectionalLight3D properties on every moon after the zone applied
##   --env=k:v,...               Environment properties on the zone's environment
##   --grade=k:v,...             grade shader parameters
##   --rs=atlas:4096,filter:2,pfilter:2,fogvol:64x48   RenderingServer settings
##   --strip=16                  frames of camera motion after the still (0 = none)
##   --move=0.015                metres per frame the player slides forward during the strip
##   --turn=0.0                  radians per frame the view turns during the strip
##   --crop=x,y,w,h              strip / flicker region in output pixels (default lower middle)
##   --scaling=fsr|full|bilinear  3D upscale mode (full = no upscale)   --fsr_sharp=0.2
##   --shader=res://a.gdshader=/abs/b.gdshader   run with b's code in a (A/B a shader edit)
##   --flame=r,g,b               brazier flame particle albedo (A/B the blow-out)
##   --debug=14                  Viewport debug draw (14 = PSSM splits, 2 = lighting only)
## Flicker: mean |dL| between consecutive strip frames inside the crop (0..255) and the share of
## pixels that jump more than 10/255. Run with --grade=grain:0 for a clean number.
const CAP_S := 240.0
var VIEWS := [
	["cart", Vector3(14.0, NAN, 16.0), 2.6, -0.32],
	["spawn", Vector3(0.0, NAN, 30.0), PI * 0.5, -0.22],
	["meadow", Vector3(-20.0, NAN, 40.0), 2.4, -0.2],
	["glade", Vector3(-30.0, NAN, 14.0), 1.1, -0.2],
	["tavern", Vector3(12.0, -0.5, 27.0), -0.9, -0.12],
]
const SETTLE := 45
var p: Player
var main: Node
var i := -1
var wait := 0
var strip_n := 16
var strip_at := -1
var move := 0.015
var turn := 0.0
var crop := Rect2i(560, 560, 800, 400)
var tag := "now"
var moon_props := {}
var env_props := {}
var grade_props := {}
var tuned := false
var frames: Array[Image] = []
var base_pos := Vector3.ZERO
var started := 0
var _held: Array[Resource] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	started = Time.get_ticks_msec()
	Travel._busy = true   # never write Luke's save from a capture run
	var preset := 2
	var sets := ""
	var custom := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preset="):
			preset = int(a.trim_prefix("--preset="))
	Settings.set_preset_fields(preset)
	Settings.fov = 90.0
	Settings.fullscreen = false
	Settings.window_size_index = 2
	Settings.vsync = false
	Settings.fps_limit = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--view="):
			if not custom:
				VIEWS = []
				custom = true
			var v := a.trim_prefix("--view=").split(",")
			VIEWS.append([v[0], Vector3(float(v[1]), NAN if v[2] == "nan" else float(v[2]), float(v[3])), float(v[4]), float(v[5])])
		elif a.begins_with("--moon="):
			moon_props = _kv(a.trim_prefix("--moon="))
		elif a.begins_with("--env="):
			env_props = _kv(a.trim_prefix("--env="))
		elif a.begins_with("--grade="):
			grade_props = _kv(a.trim_prefix("--grade="))
		elif a.begins_with("--strip="):
			strip_n = int(a.trim_prefix("--strip="))
		elif a.begins_with("--move="):
			move = float(a.trim_prefix("--move="))
		elif a.begins_with("--turn="):
			turn = float(a.trim_prefix("--turn="))
		elif a.begins_with("--crop="):
			var c := a.trim_prefix("--crop=").split(",")
			crop = Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))
		elif a.begins_with("--set="):
			sets = a.trim_prefix("--set=")
		elif a.begins_with("--shader="):        # res://a.gdshader=/abs/b.gdshader: b's code in a (memory only)
			var parts := a.trim_prefix("--shader=").split("=")
			var sh := load(parts[0]) as Shader
			var code := FileAccess.get_file_as_string(parts[1])
			if sh and code != "":
				sh.code = code
				_held.append(sh)
				print("LINES shader variant %s <- %s" % [parts[0], parts[1].get_file()])
		elif a.begins_with("--debug="):
			get_viewport().debug_draw = int(a.trim_prefix("--debug=")) as Viewport.DebugDraw
		elif a.begins_with("--rs="):
			for kv in a.trim_prefix("--rs=").split(","):
				var k := kv.get_slice(":", 0)
				var val := kv.get_slice(":", 1)
				match k:
					"atlas":
						RenderingServer.directional_shadow_atlas_set_size(int(val), true)
					"filter":
						RenderingServer.directional_soft_shadow_filter_set_quality(int(val))
					"pfilter":
						RenderingServer.positional_soft_shadow_filter_set_quality(int(val))
					"fogvol":
						RenderingServer.environment_set_volumetric_fog_volume_size(int(val.get_slice("x", 0)), int(val.get_slice("x", 1)))
					"ssao":
						RenderingServer.environment_set_ssao_quality(int(val) as RenderingServer.EnvironmentSSAOQuality, true, 0.5, 2, 50.0, 300.0)
				print("LINES rs ", k, " = ", val)
	if sets != "":
		for kv in sets.split(","):
			var k := kv.get_slice(":", 0)
			var val := kv.get_slice(":", 1)
			var cur: Variant = Settings.get(k)
			Settings.set(k, (val == "true") if cur is bool else (float(val) if cur is float else int(val)))
	print("LINES config preset %d shadows %d ssr %s ssao %s aa %d detail %d fov %.0f tag %s" % [preset, Settings.shadow_quality,
		Settings.ssr_enabled, Settings.ssao_enabled, Settings.aa_mode, Settings.detail, Settings.fov, tag])
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _kv(s: String) -> Dictionary:
	var d := {}
	for kv in s.split(","):
		d[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
	return d


func _quit(code := 0) -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit(code)


func _process(_d: float) -> void:
	if Time.get_ticks_msec() - started > int(CAP_S * 1000.0):
		print("LINES timeout")
		_quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if Realm.enabled() and not main.has_meta("realm_done"):
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	if not tuned:
		_tune()
		return
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	if i >= 0 and i < VIEWS.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0 and strip_at < 0:
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://shots/critE_lines_%s_%s.png" % [VIEWS[i][0], tag]))
		if strip_n > 0:
			strip_at = 0
			frames.clear()
			return
	elif i >= 0 and strip_at >= 0:
		var img := get_viewport().get_texture().get_image()
		frames.append(img.get_region(crop))
		strip_at += 1
		if strip_at < strip_n:
			return
		_strip(VIEWS[i][0])
		strip_at = -1
	i += 1
	if i >= VIEWS.size():
		print("LINES done")
		_quit(0)
		return
	var v: Array = VIEWS[i]
	base_pos = v[1]
	if is_nan(base_pos.y):
		base_pos.y = _ground(base_pos) + 0.05
	_hold()
	p.set_view(float(v[2]), float(v[3]))
	wait = SETTLE


func _tune() -> void:
	tuned = true
	for d in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		for k: String in moon_props:
			d.set(k, moon_props[k])
		var m := d as DirectionalLight3D
		print("LINES moon %s on %s bias %.3f normal %.2f mode %d max %.0f split1 %.2f blend %s fade %.2f angular %.2f" % [m.name, m.shadow_enabled,
			m.shadow_bias, m.shadow_normal_bias, m.directional_shadow_mode, m.directional_shadow_max_distance,
			m.directional_shadow_split_1, m.directional_shadow_blend_splits, m.directional_shadow_fade_start, m.light_angular_distance])
	var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	for w in we:
		var env := (w as WorldEnvironment).environment
		for k: String in env_props:
			var cur: Variant = env.get(k)
			env.set(k, bool(env_props[k]) if cur is bool else (int(env_props[k]) if cur is int else env_props[k]))
		print("LINES env vol %s ssao %s ssr %s steps %d sdfgi %s" % [env.volumetric_fog_enabled, env.ssao_enabled, env.ssr_enabled, env.ssr_max_steps, env.sdfgi_enabled])
	var g := main.get_node_or_null("Grade/Rect") as ColorRect
	if g and g.material is ShaderMaterial:
		for k: String in grade_props:
			(g.material as ShaderMaterial).set_shader_parameter(k, grade_props[k])
	var vp := get_viewport()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--flame="):           # r,g,b albedo on every brazier Flame's particle material
			var c := a.trim_prefix("--flame=").split(",")
			for fl in get_tree().root.find_children("Flame", "GPUParticles3D", true, false):
				var q := (fl as GPUParticles3D).draw_pass_1 as QuadMesh
				if q and q.material is StandardMaterial3D:
					(q.material as StandardMaterial3D).albedo_color = Color(float(c[0]), float(c[1]), float(c[2]))
		if a.begins_with("--scaling="):      # bilinear | fsr | full (3D at the output's own rows)
			var m := a.trim_prefix("--scaling=")
			if m == "full":
				vp.scaling_3d_scale = 1.0
			else:
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if m == "fsr" else Viewport.SCALING_3D_MODE_BILINEAR
		elif a.begins_with("--fsr_sharp="):
			vp.fsr_sharpness = float(a.trim_prefix("--fsr_sharp="))
	print("LINES viewport %s scale %.3f mode %d aa ss %d taa %s msaa %d" % [vp.get_visible_rect().size, vp.scaling_3d_scale, vp.scaling_3d_mode,
		vp.screen_space_aa, vp.use_taa, vp.msaa_3d])


func _ground(at: Vector3) -> float:
	var space := (p as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 120.0, at.z), Vector3(at.x, -60.0, at.z), 1)
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if hit else 0.0


func _hold() -> void:
	var pos := base_pos
	if strip_at >= 0:
		var fwd := Vector3(-sin(float(VIEWS[i][2])), 0.0, -cos(float(VIEWS[i][2])))
		pos += fwd * move * float(strip_at)
		p.set_view(float(VIEWS[i][2]) + turn * float(strip_at), float(VIEWS[i][3]))
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


## Filmstrip (frames side by side, at most 8 per row) and the flicker numbers.
func _strip(view: String) -> void:
	var w := crop.size.x
	var h := crop.size.y
	var cols := mini(frames.size(), 4)
	var rows := ceili(float(frames.size()) / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	var sum := 0.0
	var jumps := 0
	var n := 0
	var prev := PackedByteArray()
	for k in frames.size():
		var im := frames[k]
		im.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
		var data := im.get_data()
		if prev.size() == data.size():
			for o in range(0, data.size(), 3):
				var l1 := 0.2126 * data[o] + 0.7152 * data[o + 1] + 0.0722 * data[o + 2]
				var l0 := 0.2126 * prev[o] + 0.7152 * prev[o + 1] + 0.0722 * prev[o + 2]
				var dl := absf(l1 - l0)
				sum += dl
				if dl > 10.0:
					jumps += 1
				n += 1
		prev = data
	sheet.save_png(ProjectSettings.globalize_path("res://shots/critE_lines_%s_%s_strip.png" % [view, tag]))
	print("LINES flicker %s %s mean_dL %.2f jumps>10 %.2f%% over %d frames (move %.3f m, turn %.4f rad /frame)" % [view, tag,
		sum / maxf(n, 1.0), 100.0 * float(jumps) / maxf(n, 1.0), frames.size(), move, turn])

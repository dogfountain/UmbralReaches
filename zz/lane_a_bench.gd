extends Node
## Image-pipeline A/B bench (lane A, r35): one run, the real player camera, a variant switched on and
## off in short alternating windows, many reps, medians. Other work on the GPU only adds noise that
## both halves of a pair share, so the paired difference is what to read.
##   godot --path . res://zz/lane_a_bench.tscn -- --var=deband [--var=fogres:32:16 ...] [--stress=2]
##        [--preset=1] [--reps=12] [--win=24] [--views=spawn,summit] [--shots] [--frames-only]
## Variants (B = with, A = without):
##   deband            root viewport debanding
##   fogres:S:D        volumetric fog froxels S x D against the project's 24 x 12
##   ssil              screen-space indirect light on
##   ssao_q:Q          SSAO quality Q against the project's (0)
##   ssao_full         SSAO at full resolution against half
##   agx_c:C           AgX contrast C (default 1.25)
##   agx_w:W           AgX white W (default 16.29)
##   env:prop:V        any Environment float property set to V (e.g. env:tonemap_white:1)
##   grade_off         the grade hidden (what the whole pass costs)
##   grade:/abs/x.gdshader   the grade's code swapped for x's
## --nograde hides the grade. --shots saves shots/lanea_<view>_<var>_<A|B>.png per view and variant.
## Settings are set in memory only and saves are blocked (Travel._busy).

var VIEWS := {
	"spawn": [Vector3(0.0, 0.2, 24.0), 0.0, -0.06],
	"meadow": [Vector3(-20.0, 0.3, 40.0), 2.4, -0.04],
	"henge": [Vector3(-62.0, 8.0, -12.0), 0.9, -0.05],
	"fen": [Vector3(62.0, 0.0, 6.0), -0.6, -0.06],
	"crossing": [Vector3(0.0, 0.8, -10.0), 0.0, 0.05],
	"tavern": [Vector3(12.0, -0.5, 27.0), -0.9, -0.08],
	"summit": [Vector3(0.0, 27.9, -92.0), 0.0, -0.05],
	"thornwood": [Vector3(-80.0, 3.0, 10.0), 0.4, -0.02],
}
var views: Array = ["spawn", "summit"]
var variants: Array = []
var reps := 12
var win := 24
var shots := false
var nograde := false     ## --nograde: grade hidden (see the raw tonemapped frame)
var p: Player
var main: Node
var env: Environment
var grade_sh: Shader
var grade_code := ""
var ready_t := -1.0
var t := 0.0
# state machine
var vi := 0          # view index
var ki := 0          # variant index
var rep := 0
var half := 0        # 0 = A (off), 1 = B (on); order flips every rep
var frame := -1      # frames into the window; negative = settling
var acc := 0.0
var res := {}        # "view|var" -> [[a_ms, b_ms], ...]
var env_keep := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stress := 0.0
	var preset := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--var="):
			variants.append(a.trim_prefix("--var="))
		elif a.begins_with("--stress="):
			stress = float(a.trim_prefix("--stress="))
		elif a.begins_with("--preset="):
			preset = int(a.trim_prefix("--preset="))
		elif a.begins_with("--reps="):
			reps = int(a.trim_prefix("--reps="))
		elif a.begins_with("--win="):
			win = int(a.trim_prefix("--win="))
		elif a.begins_with("--views="):
			views = Array(a.trim_prefix("--views=").split(","))
		elif a == "--shots":
			shots = true
		elif a == "--nograde":
			nograde = true
	Settings.set_preset_fields(preset)
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.fps_limit = 0
	Settings.render_scale = stress if stress > 0.0 else 0.0
	Settings.fov = 90.0
	Travel._busy = true
	print("LANEA config preset %d stress %.1f reps %d win %d variants %s" % [preset, stress, reps, win, variants])
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _apply_var(on: bool, v: String) -> void:
	var parts := v.split(":")
	var vp := get_viewport()
	match parts[0]:
		"deband":
			vp.use_debanding = on
		"fogres":
			if on:
				RenderingServer.environment_set_volumetric_fog_volume_size(int(parts[1]), int(parts[2]))
			else:
				RenderingServer.environment_set_volumetric_fog_volume_size(24, 12)
		"ssil":
			env.ssil_enabled = on
		"ssao_q":
			RenderingServer.environment_set_ssao_quality((int(parts[1]) if on else 0) as RenderingServer.EnvironmentSSAOQuality, true, 0.5, 2, 50.0, 300.0)
		"ssao_full":
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, not on, 0.5, 2, 50.0, 300.0)
		"agx_c":
			env.tonemap_agx_contrast = float(parts[1]) if on else 1.25
		"agx_w":
			env.tonemap_agx_white = float(parts[1]) if on else 16.29
		"env":
			if not env_keep.has(parts[1]):
				env_keep[parts[1]] = env.get(parts[1])
			env.set(parts[1], float(parts[2]) if on else env_keep[parts[1]])
		"grade_off":
			(main.get_node("Grade") as CanvasLayer).visible = not on
		"grade":
			grade_sh.code = FileAccess.get_file_as_string(v.trim_prefix("grade:")) if on else grade_code


func _process(d: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not p.get_parent().has_meta("realm_done"):
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	if env == null:
		env = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
		var rect := main.get_node("Grade/Rect") as ColorRect
		grade_sh = (rect.material as ShaderMaterial).shader
		grade_code = grade_sh.code
		ready_t = 0.0
		_go_view()
		frame = -240            # post-build (lava, chunks) and shader warm-up
		return
	_hold()
	if frame < 0:
		frame += 1
		return
	if frame == 0:
		acc = 0.0
	elif frame <= win:
		acc += d * 1000.0
	frame += 1
	if frame <= win:
		return
	_end_window()


func _key() -> String:
	return "%s|%s" % [views[vi], variants[ki]]


func _end_window() -> void:
	var ms := acc / float(win)
	var k := _key()
	if not res.has(k):
		res[k] = []
	var on_b := (half == 1) != (rep % 2 == 1)      # ABBA ordering
	if half == 0:
		res[k].append([0.0, 0.0])
	res[k][rep][1 if on_b else 0] = ms
	half += 1
	if half == 2:
		half = 0
		rep += 1
		if rep >= reps:
			_report(k)
			_apply_var(false, variants[ki])
			if shots:
				await _shot_pair()
			rep = 0
			ki += 1
			if ki >= variants.size():
				ki = 0
				vi += 1
				if vi >= views.size():
					print("LANEA done")
					get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
					OS.kill(OS.get_process_id())
					return
				_go_view()
				frame = -90
				return
	var nb := (half == 1) != (rep % 2 == 1)
	_apply_var(nb, variants[ki])
	frame = -6                  # let the switch land (and any pipeline compile) outside the window


func _shot_pair() -> void:
	frame = -100000
	var vname := String(variants[ki]).replace(":", "_").replace("/", "_")
	if vname.begins_with("grade"):
		vname = "grade_" + String(variants[ki]).get_file().get_basename()
	for on in [false, true]:
		_apply_var(on, variants[ki])
		for _i in 30:
			await get_tree().process_frame
		var path := ProjectSettings.globalize_path("res://shots/lanea_%s_%s_%s.png" % [views[vi], vname, "B" if on else "A"])
		get_viewport().get_texture().get_image().save_png(path)
	_apply_var(false, variants[ki])
	frame = -6


func _report(k: String) -> void:
	var a: Array = []
	var b: Array = []
	var dd: Array = []
	for pr: Array in res[k]:
		a.append(pr[0])
		b.append(pr[1])
		dd.append(pr[1] - pr[0])
	a.sort()
	b.sort()
	dd.sort()
	var wins := dd.filter(func(x: float) -> bool: return x > 0.0).size()
	print("LANEA %-28s A %6.2f ms  B %6.2f ms  B-A median %+6.2f ms  (B slower in %d/%d pairs; pair diffs %s)" % [
		k, a[a.size() / 2], b[b.size() / 2], dd[dd.size() / 2], wins, dd.size(),
		", ".join(dd.map(func(x: float) -> String: return "%+.2f" % x))])


func _go_view() -> void:
	var v: Array = VIEWS[views[vi]]
	_hold()
	p.set_view(float(v[1]), float(v[2]))


func _hold() -> void:
	var v: Array = VIEWS[views[vi]]
	p.global_position = v[0]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.set_view(float(v[1]), float(v[2]))    # every frame: the idle camera otherwise drifts between A and B shots

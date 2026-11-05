class_name Zone
extends Node3D
## Shared shell for a playable night. A zone owns grade, settings, window scale, and lights.
## Unique atmosphere, props, and tools stay in the child script; call finish_zone_setup() last.

@onready var _grade: CanvasLayer = $Grade
@onready var _grade_mat: ShaderMaterial = ($Grade/Rect as ColorRect).material
@onready var _player: Player = $Player
@onready var _env: Environment = ($WorldEnvironment as WorldEnvironment).environment
@onready var _moon: DirectionalLight3D = $Moon
@onready var _cam: Camera3D = $Player/CameraRig/Pitch/SpringArm/Camera

var _gloom_target := 0.0
var _gloom_vis := 0.0
const QUICK_SCALES := [0.0, 1.0, 0.85, 0.7, 0.5]
var _quick_scale_step := 0
var _lights: Array[Light3D] = []
var _applied_size_index := -1
var _boot_t0 := 0


func _ready() -> void:
	_boot_t0 = Time.get_ticks_usec()
	# cover the build and the shader warm-up (ui/loading_screen.gd; skipped under zz/ harnesses)
	(load("res://ui/loading_screen.gd") as GDScript).call("open", self)
	Events.gloom_changed.connect(func(v: float, m: float) -> void: _gloom_target = v / m)
	Events.player_hurt.connect(_on_player_hurt)
	get_window().size_changed.connect(_on_window_resized)
	Settings.changed.connect(_apply_settings)


func finish_zone_setup() -> void:
	if get_node_or_null("BoltPool") == null:
		var pool := BoltPool.new()
		pool.name = "BoltPool"
		add_child(pool)
	refresh_lights()
	_apply_settings()
	call_deferred("_restore_kindles")
	_diag_later()
	print("BOOT setup_ms=%.1f" % ((Time.get_ticks_usec() - _boot_t0) * 0.001))
	_log_first_frame()


func _log_first_frame() -> void:
	await get_tree().process_frame
	print("BOOT first_frame_ms=%.1f driver=%s method=%s" % [
		(Time.get_ticks_usec() - _boot_t0) * 0.001,
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method()])


func _diag_later() -> void:
	if not OS.is_debug_build() and "--diag" not in OS.get_cmdline_user_args():
		return
	var tree := get_tree()
	if tree == null:
		push_error("Zone._diag_later tree null")
		return
	await tree.create_timer(0.45).timeout
	if not is_instance_valid(self):
		return
	BootDiag.run(self)


func _restore_kindles() -> void:
	Travel.restore_kindles(self)


var _hurt := 0.0


func _on_player_hurt(amount: float, from_pos: Vector3) -> void:
	_hurt = clampf(0.5 + amount / 40.0, 0.5, 1.0)
	var dir := Vector2.ZERO
	if from_pos != Vector3.INF and _cam:
		var to := from_pos - _cam.global_position
		var local := _cam.global_basis.inverse() * to
		dir = Vector2(local.x, -local.z).normalized() * Vector2(1.0, -1.0)   # screen x right, y down
	_grade_mat.set_shader_parameter("hurt_dir", dir)
	_grade_mat.set_shader_parameter("hurt", _hurt)


var _spawn_checked := false


## The save's checkpoint is where the wanderer wakes. A save from an older layout (a brazier that
## moved, the pre-Realm world) or a damaged one could put that point inside rock or over nothing:
## once the night is built, check it, and wake at the spawn brazier instead if it is not standable.
func _check_saved_spawn() -> void:
	_spawn_checked = true
	var saved := Travel.checkpoint_for(scene_file_path)
	if saved == Vector3.INF or _player == null:
		return
	# the player was moved since (a test, a portal): leave them. Falling straight down from the point
	# (it was over nothing) still counts as being there.
	var p := _player.global_position
	if Vector2(p.x - saved.x, p.z - saved.z).length() > 1.0:
		return
	var why := _unstandable(saved)
	if why == "":
		return
	# first try the ground right there (an old save from before a brazier's point was dropped onto
	# the ground), then the spawn brazier
	var to := Vector3.INF
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(saved + Vector3.UP * 3.0, saved + Vector3.DOWN * 6.0, Layers.WORLD | Layers.PROPS, [_player.get_rid()]))
	if not hit.is_empty() and (hit.normal as Vector3).y > 0.7:
		var near := (hit.position as Vector3) + Vector3.UP * 0.15
		if _unstandable(near) == "":
			to = near
	if to == Vector3.INF:
		var sanct := get_node_or_null("Zone/Braziers/Sanctuary")
		to = sanct.call("spawn_point") if sanct and sanct.has_method("spawn_point") else Vector3(0.0, 0.4, 26.5)
	push_warning("Zone: saved checkpoint %s is %s; waking at %s instead" % [saved, why, to])
	_player.teleport(to)
	_player.set_checkpoint(to)                   # the save gets the corrected point too


## "" if a body can stand at `at` (ground within 30 m below, no solid at chest height), else why not.
func _unstandable(at: Vector3) -> String:
	var space := get_world_3d().direct_space_state
	var mask := Layers.WORLD | Layers.PROPS
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 30.0, mask, [_player.get_rid()])
	if space.intersect_ray(ray).is_empty():
		return "over nothing (or under the ground)"
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.0
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0)
	q.collision_mask = mask
	q.exclude = [_player.get_rid()]
	if not space.intersect_shape(q, 1).is_empty():
		return "inside a solid"
	return ""


func _process(delta: float) -> void:
	if not _spawn_checked and (has_meta("realm_done") or (not Realm.enabled() and Engine.get_process_frames() > 30)):
		_check_saved_spawn()
	RenderingServer.global_shader_parameter_set("sky_time", Time.get_ticks_msec() * 0.001)
	if _hurt > 0.0:
		_hurt = maxf(0.0, _hurt - delta * 2.2)
		_grade_mat.set_shader_parameter("hurt", _hurt)
	var next := move_toward(_gloom_vis, _gloom_target, delta * 0.8)
	if not is_equal_approx(next, _gloom_vis):
		_gloom_vis = next
		_grade_mat.set_shader_parameter("gloom", _gloom_vis)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_grade"):
		Settings.grade_enabled = not Settings.grade_enabled
		Settings.apply()
	elif event.is_action_pressed("render_scale"):
		_quick_scale_step = (_quick_scale_step + 1) % QUICK_SCALES.size()
		Settings.render_scale = QUICK_SCALES[_quick_scale_step]
		Settings.apply()
	elif event.is_action_pressed("fullscreen"):
		Settings.fullscreen = not Settings.fullscreen
		Settings.apply()


func _apply_settings() -> void:
	var w := get_window()
	if _moving_screen:
		return                      # _move_to_screen re-applies everything once the window lands
	if _wants_other_screen():
		_move_to_screen(Settings.monitor)
		return
	var want_mode := Window.MODE_FULLSCREEN if Settings.fullscreen else Window.MODE_WINDOWED
	if w.mode != want_mode:
		w.mode = want_mode
	if not Settings.fullscreen and Settings.window_size_index != _applied_size_index:
		w.size = Settings.WINDOW_SIZES[clampi(Settings.window_size_index, 0, Settings.WINDOW_SIZES.size() - 1)]
	_applied_size_index = Settings.window_size_index
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Settings.vsync else DisplayServer.VSYNC_DISABLED)
	_apply_output()
	_apply_render_scale()
	_apply_aa()
	Atmosphere.apply_zone_settings(self, _env, _cam, _moon)
	_grade.visible = Settings.grade_enabled
	_cam.fov = Settings.fov
	_player.mouse_sensitivity = Settings.mouse_sensitivity
	if "stick_sensitivity" in _player:
		_player.set("stick_sensitivity", Settings.stick_sensitivity)
	_player.invert_y = Settings.invert_y
	Engine.max_fps = Settings.effective_max_fps()
	var blur := MotionBlur.attach(_cam)
	if blur:
		blur.strength = Settings.motion_blur


func cached_lights() -> Array:
	return _lights


func refresh_lights() -> void:
	_lights.clear()
	for node in find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light:
			_lights.append(light)


func _on_window_resized() -> void:
	_apply_output()
	_apply_render_scale()
	Engine.max_fps = Settings.effective_max_fps()   # a new screen may have another refresh rate


# --- monitors ------------------------------------------------------------------------------------

var _moving_screen := false
var _screen_tried := -1        # one move per choice: if the OS refuses, don't retry every apply


func _wants_other_screen() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var m := Settings.monitor
	if m != _screen_tried:
		_screen_tried = -1
	return m >= 0 and m != _screen_tried and m < DisplayServer.get_screen_count() and DisplayServer.window_get_current_screen() != m


## macOS will not move a fullscreen window between displays: leave fullscreen, move (centred),
## then go back, a couple of frames apart so each change lands before the next.
func _move_to_screen(m: int) -> void:
	_moving_screen = true
	_screen_tried = m
	var w := get_window()
	if w.mode != Window.MODE_WINDOWED:
		w.mode = Window.MODE_WINDOWED
		for _i in 3:
			await get_tree().process_frame
	w.current_screen = m
	var area := DisplayServer.screen_get_usable_rect(m)
	w.position = area.position + (area.size - w.size) / 2
	for _i in 2:
		await get_tree().process_frame
	_moving_screen = false
	_apply_settings()


# --- output resolution ----------------------------------------------------------------------------

## On a 4K / Retina screen render the whole frame (3D, post, grade, UI) at OUTPUT_BASE (expanded to
## the screen's aspect) and let one stretch blit fill the window, unless the player wants native.
func _apply_output() -> void:
	var w := get_window()
	var big := w.size.y > int(Settings.OUTPUT_BASE.y * 1.15)
	var mode := Window.CONTENT_SCALE_MODE_VIEWPORT if big and not Settings.native_output else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if w.content_scale_mode != mode:
		w.content_scale_mode = mode
	# the UI is laid out on a 1920x1080 canvas scaled to the window: at 1280x720 that shrank every
	# font to 2/3 (15 px text drew 10 px tall). Windows under 864 rows get a 1600x900 canvas instead
	# (text 20 % larger; every panel is under 810 canvas rows, so all still fit)
	var base := Settings.OUTPUT_BASE
	if mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and w.size.y < 864:
		base = Vector2i(1600, 900)
	if w.content_scale_size != base:
		w.content_scale_size = base


## Rows the final image is rendered at: the window's, or the reduced output's.
func output_height() -> int:
	var w := get_window()
	if w.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		return roundi(get_viewport().get_visible_rect().size.y)
	return w.size.y


## Anti-aliasing on the root viewport (Settings.aa_mode): one method at a time.
func _apply_aa() -> void:
	var vp := get_viewport()
	var m := Settings.aa_mode
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if m == 1 else (Viewport.SCREEN_SPACE_AA_SMAA if m == 2 else Viewport.SCREEN_SPACE_AA_DISABLED)
	vp.use_taa = m == 3
	vp.msaa_3d = Viewport.MSAA_2X if m == 4 else (Viewport.MSAA_4X if m == 5 else Viewport.MSAA_DISABLED)


func _apply_render_scale() -> void:
	var vp := get_viewport()
	var cap_scale := minf(1.0, float(Settings.render_height_cap()) / float(maxi(output_height(), 1)))
	var want := Settings.render_scale
	if want <= 0.0:
		want = 1.0
	# (r29, agent E) below 1:1 (the 960-row cap at 1080) the upscale is FSR 1 with its least RCAS
	# sharpening: bilinear at 8/9 left a 9-px grid of soft and sharp rows and columns over the whole
	# frame (gradient energy 1.5-1.9x apart, zz/perf_lines --scaling=), which crawled as lines under
	# the grade's sharpen whenever the camera moved. Above 1:1 (supersampling) bilinear is right.
	var s := want * cap_scale
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if s < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.fsr_sharpness = 2.0
	vp.scaling_3d_scale = s

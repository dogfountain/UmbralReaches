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
var _omni_lights: Array[OmniLight3D] = []
var _applied_size_index := -1
var _boot_t0 := 0


func _ready() -> void:
	_boot_t0 = Time.get_ticks_usec()
	Events.gloom_changed.connect(func(v: float, m: float) -> void: _gloom_target = v / m)
	get_window().size_changed.connect(_on_window_resized)
	Settings.changed.connect(_apply_settings)


func finish_zone_setup() -> void:
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
	var tree := get_tree()
	if tree == null:
		push_error("Zone._diag_later tree null")
		return
	await tree.create_timer(0.45).timeout
	if not is_instance_valid(self):
		return
	var diag := load("res://core/debug/boot_diag.gd")
	if diag == null:
		push_error("Zone: boot_diag.gd failed to load")
		return
	diag.run(self)


func _restore_kindles() -> void:
	Travel.restore_kindles(self)


func _process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set("sky_time", Time.get_ticks_msec() * 0.001)
	_gloom_vis = move_toward(_gloom_vis, _gloom_target, delta * 0.8)
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
	var want_mode := Window.MODE_FULLSCREEN if Settings.fullscreen else Window.MODE_WINDOWED
	if w.mode != want_mode:
		w.mode = want_mode
	if not Settings.fullscreen and Settings.window_size_index != _applied_size_index:
		w.size = Settings.WINDOW_SIZES[clampi(Settings.window_size_index, 0, Settings.WINDOW_SIZES.size() - 1)]
	_applied_size_index = Settings.window_size_index
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Settings.vsync else DisplayServer.VSYNC_DISABLED)
	_apply_render_scale()
	load("res://core/world/atmosphere.gd").apply_zone_settings(self, _env, _cam, _moon)
	_grade.visible = Settings.grade_enabled
	_cam.fov = Settings.fov
	_player.mouse_sensitivity = Settings.mouse_sensitivity


func refresh_lights() -> void:
	_omni_lights.clear()
	for light in get_tree().root.find_children("*", "OmniLight3D", true, false):
		_omni_lights.append(light)


func _on_window_resized() -> void:
	_apply_render_scale()


func _apply_render_scale() -> void:
	var vp := get_viewport()
	var cap_scale := minf(1.0, float(Settings.render_height_cap()) / float(maxi(get_window().size.y, 1)))
	var want := Settings.render_scale
	if want <= 0.0:
		want = 1.0
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = want * cap_scale

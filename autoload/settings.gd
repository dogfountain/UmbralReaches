extends Node
## Persistent graphics/video/camera settings (user://settings.cfg). Pure data + persistence --
## ui/settings_menu.gd edits these fields and calls save(); world/main.gd listens for `changed`
## and actually applies them to the live scene (window, environment, lights, camera).

signal changed

const PATH := "user://settings.cfg"
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const SHADOW_NAMES := ["Off", "Low", "High"]
const PRESET_NAMES := ["Performance", "Balanced", "Cinematic"]
const SAVE_DELAY := 0.75        # seconds of quiet before the file is actually written

var _save_timer := 0.0
var _save_pending := false
var _emit_queued := false

var fullscreen := false
var window_size_index := 1          # index into WINDOW_SIZES
var vsync := true
var render_scale := 0.0             # 0 = auto, else 0.5-1.0 fixed
var shadow_quality := 2             # 0 off, 1 low, 2 high
var fog_enabled := true
var ssao_enabled := true
var glow_enabled := true
var grade_enabled := true
var dof_enabled := false
var ssr_enabled := false
var quality_preset := 1             # 0 Performance, 1 Balanced, 2 Cinematic
var fov := 54.0
var mouse_sensitivity := 0.0025


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the debounce keeps ticking while the menu pauses the world
	load_settings()
	set_process(false)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	window_size_index = cfg.get_value("display", "window_size_index", window_size_index)
	vsync = cfg.get_value("display", "vsync", vsync)
	render_scale = cfg.get_value("graphics", "render_scale", render_scale)
	shadow_quality = cfg.get_value("graphics", "shadow_quality", shadow_quality)
	fog_enabled = cfg.get_value("graphics", "fog_enabled", fog_enabled)
	ssao_enabled = cfg.get_value("graphics", "ssao_enabled", ssao_enabled)
	glow_enabled = cfg.get_value("graphics", "glow_enabled", glow_enabled)
	grade_enabled = cfg.get_value("graphics", "grade_enabled", grade_enabled)
	dof_enabled = cfg.get_value("graphics", "dof_enabled", dof_enabled)
	ssr_enabled = cfg.get_value("graphics", "ssr_enabled", ssr_enabled)
	quality_preset = cfg.get_value("graphics", "quality_preset", quality_preset)
	fov = cfg.get_value("camera", "fov", fov)
	mouse_sensitivity = cfg.get_value("camera", "mouse_sensitivity", mouse_sensitivity)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "window_size_index", window_size_index)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("graphics", "render_scale", render_scale)
	cfg.set_value("graphics", "shadow_quality", shadow_quality)
	cfg.set_value("graphics", "fog_enabled", fog_enabled)
	cfg.set_value("graphics", "ssao_enabled", ssao_enabled)
	cfg.set_value("graphics", "glow_enabled", glow_enabled)
	cfg.set_value("graphics", "grade_enabled", grade_enabled)
	cfg.set_value("graphics", "dof_enabled", dof_enabled)
	cfg.set_value("graphics", "ssr_enabled", ssr_enabled)
	cfg.set_value("graphics", "quality_preset", quality_preset)
	cfg.set_value("camera", "fov", fov)
	cfg.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(PATH)


## Call after editing any field to push the change into the live scene. The disk write is
## debounced: dragging a slider fires this once per frame, and each write is a full file rewrite.
func apply() -> void:
	_save_pending = true
	_save_timer = SAVE_DELAY
	set_process(true)
	if _emit_queued:
		return
	_emit_queued = true
	call_deferred("_emit_changed")


func _emit_changed() -> void:
	_emit_queued = false
	changed.emit()


func _process(delta: float) -> void:
	_save_timer -= delta
	if _save_timer <= 0.0:
		flush()


## Write any debounced change out now -- on menu close, and on the way out of the tree.
func flush() -> void:
	set_process(false)
	if _save_pending:
		_save_pending = false
		save_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		flush()


func reset_defaults() -> void:
	fullscreen = false
	window_size_index = 1
	vsync = true
	render_scale = 0.0
	fov = 54.0
	mouse_sensitivity = 0.0025
	apply_preset(1)


## Internal render height. A 1440-tall buffer is ~2300px wide on this panel, and cinematic
## (fog, SSAO, glow, depth of field, SSR) cannot hold 120Hz there. 960 keeps those effects on.
func render_height_cap() -> int:
	return 960


func apply_preset(index: int) -> void:
	quality_preset = clampi(index, 0, 2)
	match quality_preset:
		0:
			shadow_quality = 1
			fog_enabled = true
			ssao_enabled = false
			glow_enabled = true
			grade_enabled = true
			dof_enabled = false
			ssr_enabled = false
		1:
			shadow_quality = 2
			fog_enabled = true
			ssao_enabled = true
			glow_enabled = true
			grade_enabled = true
			dof_enabled = false
			ssr_enabled = false
		2:
			shadow_quality = 2
			fog_enabled = true
			ssao_enabled = true
			glow_enabled = true
			grade_enabled = true
			dof_enabled = false
			ssr_enabled = true
	apply()

extends CanvasLayer
## Graphics/video/camera settings overlay. Esc / F2 toggles it. Edits Settings (autoload) fields live;
## world/main.gd listens for Settings.changed and pushes them into the window/environment/camera.

const LILAC := Color("#A98BFF")
const QUIET := Color(0.72, 0.74, 0.86, 0.85)
const PANEL_BG := Color(0.03, 0.025, 0.07, 0.94)

var _font: Font
var _vol_sliders := {}
var _root: Control
var _panel: Panel
var _was_captured := false

var _fullscreen_btn: CheckButton
var _res_option: OptionButton
var _vsync_btn: CheckButton
var _scale_slider: HSlider
var _scale_auto_btn: CheckButton
var _scale_label: Label
var _preset_option: OptionButton
var _shadow_option: OptionButton
var _fog_btn: CheckButton
var _ssao_btn: CheckButton
var _glow_btn: CheckButton
var _grade_btn: CheckButton
var _dof_btn: CheckButton
var _ssr_btn: CheckButton
var _fov_slider: HSlider
var _fov_label: Label
var _sens_slider: HSlider
var _sens_label: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps running (and closable) while the world is paused
	_font = load("res://ui/fonts/Cinzel.ttf")

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 710)
	_panel.position = Vector2(-310, -355)
	_panel.size = Vector2(620, 710)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.5, 0.4, 0.8, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	col.add_child(_title("SETTINGS", 36, Color(0.92, 0.9, 1.0)))
	col.add_child(_spacer(8))

	col.add_child(_section("DISPLAY"))
	_fullscreen_btn = _check_row(col, "Fullscreen")
	_res_option = _option_row(col, "Window Size", ["1280 x 720", "1600 x 900", "1920 x 1080"])
	_vsync_btn = _check_row(col, "V-Sync")
	col.add_child(_spacer(10))

	col.add_child(_section("GRAPHICS"))
	_preset_option = _option_row(col, "Quality Preset", Settings.PRESET_NAMES)
	var scale_row := HBoxContainer.new()
	col.add_child(scale_row)
	scale_row.add_child(_row_label("Render Scale"))
	_scale_auto_btn = CheckButton.new()
	_scale_auto_btn.text = "Auto"
	_style_small(_scale_auto_btn)
	scale_row.add_child(_scale_auto_btn)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 1.0
	_scale_slider.step = 0.05
	_scale_slider.custom_minimum_size = Vector2(220, 24)
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(_scale_slider)
	_scale_label = _row_label("100%")
	_scale_label.custom_minimum_size = Vector2(56, 0)
	scale_row.add_child(_scale_label)

	_shadow_option = _option_row(col, "Shadow Quality", Settings.SHADOW_NAMES)
	_fog_btn = _check_row(col, "Volumetric Fog")
	_ssao_btn = _check_row(col, "Ambient Occlusion")
	_glow_btn = _check_row(col, "Glow / Bloom")
	_grade_btn = _check_row(col, "Colour Grade")
	_dof_btn = _check_row(col, "Depth of Field")
	_ssr_btn = _check_row(col, "Screen Reflections")
	col.add_child(_spacer(10))

	col.add_child(_section("AUDIO"))
	_vol_sliders.clear()
	for spec: Array in [["Master Volume", "master_volume"], ["Effects", "sfx_volume"], ["Ambience", "ambience_volume"]]:
		var vrow := HBoxContainer.new()
		col.add_child(vrow)
		vrow.add_child(_row_label(spec[0]))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(180, 0)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vrow.add_child(sl)
		var field: String = spec[1]
		sl.value_changed.connect(func(v: float) -> void:
			Settings.set(field, v)
			Settings.apply())
		_vol_sliders[field] = sl
	col.add_child(_spacer(6))
	col.add_child(_section("CAMERA"))
	var fov_row := HBoxContainer.new()
	col.add_child(fov_row)
	fov_row.add_child(_row_label("Field of View"))
	_fov_slider = HSlider.new()
	_fov_slider.min_value = 50.0
	_fov_slider.max_value = 90.0
	_fov_slider.step = 1.0
	_fov_slider.custom_minimum_size = Vector2(260, 24)
	_fov_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fov_row.add_child(_fov_slider)
	_fov_label = _row_label("58")
	_fov_label.custom_minimum_size = Vector2(56, 0)
	fov_row.add_child(_fov_label)

	var sens_row := HBoxContainer.new()
	col.add_child(sens_row)
	sens_row.add_child(_row_label("Mouse Sensitivity"))
	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.001
	_sens_slider.max_value = 0.006
	_sens_slider.step = 0.0002
	_sens_slider.custom_minimum_size = Vector2(260, 24)
	_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_row.add_child(_sens_slider)
	_sens_label = _row_label("")
	_sens_label.custom_minimum_size = Vector2(56, 0)
	sens_row.add_child(_sens_label)

	col.add_child(_spacer(16))
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	col.add_child(footer)
	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	_style_small(reset_btn)
	reset_btn.pressed.connect(_on_reset)
	footer.add_child(reset_btn)
	# two-step so a stray click cannot wipe a run
	var erase_btn := Button.new()
	erase_btn.text = "Erase Saved Progress"
	_style_small(erase_btn)
	erase_btn.pressed.connect(func() -> void:
		if erase_btn.text.begins_with("Confirm"):
			Travel.erase_save()
			erase_btn.text = "Progress erased (next launch)"
			erase_btn.disabled = true
		else:
			erase_btn.text = "Confirm: erase everything?")
	footer.add_child(erase_btn)
	var close_btn := Button.new()
	close_btn.text = "Close  (Esc)"
	_style_small(close_btn)
	close_btn.pressed.connect(close)
	footer.add_child(close_btn)

	_wire()
	_refresh_from_settings()


# --- small UI builders ------------------------------------------------------

func _title(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _section(text: String) -> Label:
	var l := _title(text, 18, LILAC)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(190, 0)
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", QUIET)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _style_small(c: Control) -> void:
	c.add_theme_font_override("font", _font)
	c.add_theme_font_size_override("font_size", 15)


func _check_row(col: VBoxContainer, label: String) -> CheckButton:
	var row := HBoxContainer.new()
	col.add_child(row)
	row.add_child(_row_label(label))
	var cb := CheckButton.new()
	row.add_child(cb)
	return cb


func _option_row(col: VBoxContainer, label: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	col.add_child(row)
	row.add_child(_row_label(label))
	var ob := OptionButton.new()
	_style_small(ob)
	for it in items:
		ob.add_item(it)
	row.add_child(ob)
	return ob


# --- wiring ------------------------------------------------------------------

func _wire() -> void:
	_fullscreen_btn.toggled.connect(func(v: bool) -> void:
		Settings.fullscreen = v
		_res_option.disabled = v
		Settings.apply())
	_res_option.item_selected.connect(func(i: int) -> void:
		Settings.window_size_index = i
		Settings.apply())
	_vsync_btn.toggled.connect(func(v: bool) -> void:
		Settings.vsync = v
		Settings.apply())
	_scale_auto_btn.toggled.connect(func(v: bool) -> void:
		_scale_slider.editable = not v
		Settings.render_scale = 0.0 if v else _scale_slider.value
		Settings.apply())
	_scale_slider.value_changed.connect(func(v: float) -> void:
		_scale_label.text = "%d%%" % roundi(v * 100.0)
		if not _scale_auto_btn.button_pressed:
			Settings.render_scale = v
			Settings.apply())
	_preset_option.item_selected.connect(func(i: int) -> void:
		Settings.apply_preset(i)
		_refresh_from_settings())
	_shadow_option.item_selected.connect(func(i: int) -> void:
		Settings.shadow_quality = i
		Settings.apply())
	_fog_btn.toggled.connect(func(v: bool) -> void:
		Settings.fog_enabled = v
		Settings.apply())
	_ssao_btn.toggled.connect(func(v: bool) -> void:
		Settings.ssao_enabled = v
		Settings.apply())
	_glow_btn.toggled.connect(func(v: bool) -> void:
		Settings.glow_enabled = v
		Settings.apply())
	_grade_btn.toggled.connect(func(v: bool) -> void:
		Settings.grade_enabled = v
		Settings.apply())
	_dof_btn.toggled.connect(func(_v: bool) -> void:
		_dof_btn.set_pressed_no_signal(false)
		Settings.dof_enabled = false
		Settings.apply())
	_ssr_btn.toggled.connect(func(v: bool) -> void:
		Settings.ssr_enabled = v
		Settings.apply())
	_fov_slider.value_changed.connect(func(v: float) -> void:
		_fov_label.text = "%d" % int(v)
		Settings.fov = v
		Settings.apply())
	_sens_slider.value_changed.connect(func(v: float) -> void:
		_sens_label.text = "%.3f" % v
		Settings.mouse_sensitivity = v
		Settings.apply())


func _refresh_from_settings() -> void:
	for field: String in _vol_sliders:
		(_vol_sliders[field] as HSlider).set_value_no_signal(float(Settings.get(field)))
	_fullscreen_btn.button_pressed = Settings.fullscreen
	_res_option.selected = Settings.window_size_index
	_res_option.disabled = Settings.fullscreen
	_vsync_btn.button_pressed = Settings.vsync
	var auto := Settings.render_scale <= 0.0
	_scale_auto_btn.button_pressed = auto
	_scale_slider.editable = not auto
	_scale_slider.value = Settings.render_scale if not auto else 1.0
	_scale_label.text = "Auto" if auto else "%d%%" % roundi(Settings.render_scale * 100.0)
	_preset_option.selected = Settings.quality_preset
	_shadow_option.selected = Settings.shadow_quality
	_fog_btn.button_pressed = Settings.fog_enabled
	_ssao_btn.button_pressed = Settings.ssao_enabled
	_glow_btn.button_pressed = Settings.glow_enabled
	_grade_btn.button_pressed = Settings.grade_enabled
	_dof_btn.button_pressed = Settings.dof_enabled
	_ssr_btn.button_pressed = Settings.ssr_enabled
	_fov_slider.value = Settings.fov
	_fov_label.text = "%d" % int(Settings.fov)
	_sens_slider.value = Settings.mouse_sensitivity
	_sens_label.text = "%.3f" % Settings.mouse_sensitivity


func _on_reset() -> void:
	Settings.reset_defaults()
	_refresh_from_settings()
	Events.toast.emit("Settings reset to defaults")


# --- open / close --------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_settings"):
		if _root.visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("release_mouse"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_root.visible = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true   # the shade used to keep hunting while the menu was up


func close() -> void:
	_root.visible = false
	Settings.flush()          # write out whatever the debounce is still holding
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

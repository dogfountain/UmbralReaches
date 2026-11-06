extends CanvasLayer
## Settings overlay. Esc / F2 / Start toggles it. Four tabs (Display, Graphics, Audio, Controls),
## each scrollable, in a padded panel that fits the window. Every control edits a Settings field
## live and calls Settings.apply(); world/main.gd (Zone) pushes them into the window/environment/
## camera. The quality preset shows "Custom" as soon as one graphics option is changed by hand.

const LILAC := Color("#A98BFF")
const QUIET := Color(0.72, 0.74, 0.86, 0.9)
const DIM := Color(0.55, 0.56, 0.68, 0.85)
const PANEL_BG := Color(0.03, 0.025, 0.07, 0.95)
const TABS := ["Display", "Graphics", "Audio", "Controls"]
const UiSound := preload("res://ui/ui_sound.gd")
const HudPrefs := preload("res://ui/hud_prefs.gd")

var _font: Font
var _root: Control
var _panel: PanelContainer
var _pages: Array[Control] = []
var _tab_btns: Array[Button] = []
var _tab := 0
var _was_captured := false
var _was_paused := false
var _tick_ms := 0
var _refreshing := false

var _fullscreen_btn: CheckButton
var _res_option: OptionButton
var _vsync_btn: CheckButton
var _fps_option: OptionButton
var _monitor_option: OptionButton
var _native_btn: CheckButton
var _pace_note: Label
var _preset_option: OptionButton
var _scale_auto_btn: CheckButton
var _scale_slider: HSlider
var _scale_label: Label
var _shadow_option: OptionButton
var _fog_btn: CheckButton
var _ssao_btn: CheckButton
var _glow_btn: CheckButton
var _grade_btn: CheckButton
var _ssr_btn: CheckButton
var _aa_option: OptionButton
var _blur_slider: HSlider
var _blur_label: Label
var _vol := {}                       # field -> [slider, label]
var _fov_slider: HSlider
var _fov_label: Label
var _sens_slider: HSlider
var _sens_label: Label
var _invert_btn: CheckButton
var _stick_slider: HSlider
var _stick_label: Label
var _hint_line: Label
var _erase_btn: Button
var _bind_btns := {}                 ## "action|slot" -> Button
var _bind_msg: Label
var _listen := ""                   ## the "action|slot" waiting for a key
var _listen_ms := 0
var on_title := false                ## opened from the title screen: no erase (no run to end), no way back to the title
var _tscale_slider: HSlider
var _tscale_label: Label


func _ready() -> void:
	layer = 70                           # the pause menu: above the HUD, the other menus and their
	                                     # banners (59-62), below the travel fade (80) and loading (120)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://ui/fonts/Cinzel.ttf")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.5, 0.4, 0.8, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	col.add_child(_title("SETTINGS", 32, Color(0.92, 0.9, 1.0)))
	# tab bar
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	col.add_child(bar)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i].to_upper()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE        # Q / E and the bumpers switch tabs; focus stays on the page
		b.custom_minimum_size = Vector2(130, 34)
		_style_small(b, 16)
		b.add_theme_color_override("font_pressed_color", LILAC)
		b.add_theme_color_override("font_color", DIM)
		var on := StyleBoxFlat.new()
		on.bg_color = Color(0.2, 0.14, 0.36, 0.9)
		on.border_color = LILAC
		on.border_width_bottom = 2
		on.set_corner_radius_all(3)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		var idx := i
		b.pressed.connect(func() -> void: _show_tab(idx))
		bar.add_child(b)
		_tab_btns.append(b)
	col.add_child(HSeparator.new())
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(640, 420)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(holder)
	for i in TABS.size():
		var scroll := ScrollContainer.new()
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true          # pad / arrow focus scrolls the page to the control
		holder.add_child(scroll)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 8)
		scroll.add_child(page)
		_pages.append(scroll)
		match i:
			0: _build_display(page)
			1: _build_graphics(page)
			2: _build_audio(page)
			3: _build_controls(page)
	# what the focused (or hovered) option does: the tooltips, readable with a pad and at a glance
	_hint_line = _label("", DIM, 15)
	_hint_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_line.custom_minimum_size = Vector2(0, 40)
	_hint_line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(_hint_line)
	get_viewport().gui_focus_changed.connect(_on_focus)
	col.add_child(HSeparator.new())
	col.add_child(_footer())
	get_viewport().size_changed.connect(_fit)
	_fit()
	_show_tab(0)
	_refresh()


# --- pages ---------------------------------------------------------------------

func _build_display(p: VBoxContainer) -> void:
	_fullscreen_btn = _check(p, "Fullscreen", "F11 toggles it in play", func(v: bool) -> void:
		Settings.fullscreen = v
		_res_option.disabled = v
		Settings.apply())
	_res_option = _option(p, "Window Size", ["1280 x 720", "1600 x 900", "1920 x 1080"], "", func(i: int) -> void:
		Settings.window_size_index = i
		Settings.apply())
	_vsync_btn = _check(p, "V-Sync", "Locks to the display's refresh rate; no tearing", func(v: bool) -> void:
		Settings.vsync = v
		Settings.apply()
		_pace_note.text = _pace_text())
	_monitor_option = _option(p, "Monitor", [], "Which display the game is shown on", func(i: int) -> void:
		Settings.monitor = i - 1          # item 0 is "Automatic"
		Settings.apply()
		_later_refresh())
	_fps_option = _option(p, "Frame Rate Limit", [], "Match Display follows the refresh rate of whichever monitor the game is on. macOS never shows more frames than the display's refresh rate, even with V-Sync off.", func(i: int) -> void:
		Settings.fps_limit = Settings.FPS_CHOICES[i]
		Settings.apply()
		_later_refresh())
	_native_btn = _check(p, "Full-Res Output (slow)", "Off: on 4K and Retina screens the frame is rendered at 1080p and scaled up once (the 3D is lower-res than that anyway). On: every pixel of the screen is rendered: sharper text, much slower.", func(v: bool) -> void:
		Settings.native_output = v
		Settings.apply()
		_later_refresh())
	_pace_note = _label("", QUIET, 15)
	_pace_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_pace_note)


func _build_graphics(p: VBoxContainer) -> void:
	_preset_option = _option(p, "Quality Preset", Settings.PRESET_NAMES + ["Custom"], "Sets everything below at once", func(i: int) -> void:
		if i < Settings.PRESET_NAMES.size():
			Settings.apply_preset(i)
		_refresh())
	_preset_option.set_item_disabled(Settings.PRESET_NAMES.size(), true)
	var row := _row(p, "Render Scale", "Below 100% renders fewer pixels: faster, softer")
	_scale_auto_btn = CheckButton.new()
	_scale_auto_btn.text = "Auto"
	_style_small(_scale_auto_btn)
	row.add_child(_scale_auto_btn)
	_scale_slider = _slider(row, 0.5, 1.0, 0.05)
	_scale_label = _value_label(row)
	_scale_auto_btn.toggled.connect(func(v: bool) -> void:
		if _refreshing:
			return
		_scale_slider.editable = not v
		Settings.render_scale = 0.0 if v else _scale_slider.value
		_scale_label.text = "Auto" if v else "%d%%" % roundi(_scale_slider.value * 100.0)
		Settings.apply())
	_scale_slider.value_changed.connect(func(v: float) -> void:
		_scale_label.text = "%d%%" % roundi(v * 100.0)
		if _refreshing or _scale_auto_btn.button_pressed:
			return
		Settings.render_scale = v
		Settings.apply())
	_shadow_option = _option(p, "Shadows", Settings.SHADOW_NAMES, "", func(i: int) -> void:
		Settings.shadow_quality = i
		_custom())
	_fog_btn = _check(p, "Volumetric Fog", "", func(v: bool) -> void:
		Settings.fog_enabled = v
		_custom())
	_ssao_btn = _check(p, "Ambient Occlusion", "Contact shadows in corners and under props", func(v: bool) -> void:
		Settings.ssao_enabled = v
		_custom())
	_glow_btn = _check(p, "Glow", "Light bleed from fires, glimmers and the sky", func(v: bool) -> void:
		Settings.glow_enabled = v
		_custom())
	_grade_btn = _check(p, "Colour Grade", "The night's tint and the gloom vignette (F1)", func(v: bool) -> void:
		Settings.grade_enabled = v
		_custom())
	_aa_option = _option(p, "Anti-Aliasing", Settings.AA_NAMES, "Smooths jagged edges. FXAA and SMAA are cheap; TAA is smoothest but can ghost in motion; MSAA smooths only geometry edges and costs the most.", func(i: int) -> void:
		Settings.aa_mode = i
		Settings.apply())
	_ssr_btn = _check(p, "Screen Reflections", "Reflections on wet stone and lava; costly", func(v: bool) -> void:
		Settings.ssr_enabled = v
		_custom())
	var brow := _row(p, "Motion Blur", "A little smear when the camera turns or runs")
	_blur_slider = _slider(brow, 0.0, 1.0, 0.05)
	_blur_label = _value_label(brow)
	_blur_slider.value_changed.connect(func(v: float) -> void:
		_blur_label.text = "Off" if v <= 0.001 else "%d%%" % roundi(v * 100.0)
		if _refreshing:
			return
		Settings.motion_blur = v
		_custom())


func _build_audio(p: VBoxContainer) -> void:
	for spec: Array in [["Master", "master_volume", "Everything at once"], ["Effects", "sfx_volume", "Spells, blows, footsteps, voices"],
			["Ambience", "ambience_volume", "Wind, rain, wildlife, fires"], ["Music", "music_volume", "The night's quiet music, which rises with danger"]]:
		var row := _row(p, spec[0], spec[2])
		var sl := _slider(row, 0.0, 1.0, 0.05)
		var lab := _value_label(row)
		var field: String = spec[1]
		sl.value_changed.connect(func(v: float) -> void:
			lab.text = "Off" if v <= 0.001 else "%d%%" % roundi(v * 100.0)
			if _refreshing:
				return
			Settings.set(field, v)
			Settings.apply())
		_vol[field] = [sl, lab]


func _build_controls(p: VBoxContainer) -> void:
	var frow := _row(p, "Field of View", "")
	_fov_slider = _slider(frow, 50.0, 90.0, 1.0)
	_fov_label = _value_label(frow)
	_fov_slider.value_changed.connect(func(v: float) -> void:
		_fov_label.text = "%d°" % int(v)
		if _refreshing:
			return
		Settings.fov = v
		Settings.apply())
	var srow := _row(p, "Mouse Sensitivity", "")
	_sens_slider = _slider(srow, 0.001, 0.006, 0.0001)
	_sens_label = _value_label(srow)
	_sens_slider.value_changed.connect(func(v: float) -> void:
		_sens_label.text = "%.1f" % (v / 0.0025 * 5.0)     # 5.0 = the default
		if _refreshing:
			return
		Settings.mouse_sensitivity = v
		Settings.apply())
	var krow := _row(p, "Stick Sensitivity", "How fast the right stick turns the view at full tilt")
	_stick_slider = _slider(krow, 1.0, 5.0, 0.1)
	_stick_label = _value_label(krow)
	_stick_slider.value_changed.connect(func(v: float) -> void:
		_stick_label.text = "%.1f" % (v / 2.6 * 5.0)       # 5.0 = the default, like the mouse
		if _refreshing:
			return
		Settings.stick_sensitivity = v
		Settings.apply())
	_invert_btn = _check(p, "Invert Look Up/Down", "Mouse and right stick", func(v: bool) -> void:
		Settings.invert_y = v
		Settings.apply())
	_build_hud(p)
	p.add_child(_spacer(6))
	p.add_child(_section("KEYS  ·  CONTROLLER"))
	_build_bindings(p)
	p.add_child(_spacer(4))
	p.add_child(_label("Fixed: Look  mouse / right stick   ·   Settings  Esc / F2 / Menu   ·   Character tabs  1 - 4, Q E", DIM, 15))


## r33: the HUD's own choices (ui/hud_prefs.gd, saved in hud.cfg): the unit frames, the floating combat
## text, what the minimap tracks (WoW's tracking menu), and the controls card on demand.
func _build_hud(p: VBoxContainer) -> void:
	HudPrefs.ensure()
	p.add_child(_spacer(6))
	p.add_child(_section("HEADS-UP DISPLAY"))
	var uf := _check(p, "Unit Frames", "Your frame, your target's and a boss's (off: the plain Gloom bar)", func(v: bool) -> void:
		HudPrefs.unit_frames = v
		HudPrefs.save())
	uf.set_pressed_no_signal(HudPrefs.unit_frames)
	var ct := _check(p, "Combat Text", "The Gloom blows put on you and kills take off, at your shoulder", func(v: bool) -> void:
		HudPrefs.combat_text = v
		HudPrefs.save())
	ct.set_pressed_no_signal(HudPrefs.combat_text)
	var plates := _check(p, "Enemy Health Bars & Plates", "Off: only the foe you are locked on to shows its bar and frame. On: a health bar over every foe, and the target frame for any foe you strike.", func(v: bool) -> void:
		HudPrefs.enemy_plates = v
		HudPrefs.save())
	plates.set_pressed_no_signal(HudPrefs.enemy_plates)
	var trow := _row(p, "Text Scale", "The size of the objective, toasts, lessons and subtitles")
	_tscale_slider = _slider(trow, 0.85, 1.5, 0.05)
	_tscale_label = _value_label(trow)
	_tscale_slider.value_changed.connect(func(v: float) -> void:
		_tscale_label.text = "%d%%" % roundi(v * 100.0)
		if _refreshing:
			return
		Settings.text_scale = v
		Settings.apply())
	var row := _row(p, "Control Prompts", "The one-line hints that appear the first time a control matters (a ledge, a foe in range...), shown again")
	var again := Button.new()
	again.text = "Show Again"
	_style_small(again, 16)
	again.pressed.connect(func() -> void:
		UiSound.play(self, "confirm")
		HudPrefs.card_request += 1
		close())
	row.add_child(again)
	p.add_child(_label("MINIMAP TRACKING", DIM, 15))
	for k: String in HudPrefs.TRACK:
		var key := k
		var cb := _check(p, String(HudPrefs.TRACK_NAMES.get(k, k.capitalize())), "Shown on the minimap", func(v: bool) -> void:
			HudPrefs.set_track(key, v))
		cb.set_pressed_no_signal(bool(HudPrefs.track.get(k, true)))


## [label, actions (their bindings are shown), keyboard text when none is in the InputMap, pad text
## to use instead of the InputMap's]
const KEY_ROWS := [
	["Move", [], "W A S D", "Left stick"], ["Look", [], "Mouse", "Right stick"],
	["Sprint", ["sprint"], "", "L3 (toggles)"], ["Jump", ["jump"], "", ""], ["Slide", ["slide"], "", ""],
	["Dodge roll", ["dodge"], "", "B (slow or locked on)"], ["Lock on", ["lock_on"], "", ""], ["Next target", ["target_next"], "T", "Flick the stick, locked"],
	["Staff strike (hold: heavy)", ["staff_strike"], "", "RT up close"], ["Guard / parry", ["guard"], "", "B held, locked on"],
	["Kindle / talk / use", ["interact"], "", ""],
	["Skills 1  ·  2", ["skill_bolt", "skill_lance"], "", ""], ["Skills 3  ·  4  ·  5", ["skill_nova", "skill_ward", "skill_step"], "", ""],
	["Character (Wanderer, Kindling, Pack, Journal)", ["inventory"], "", ""], ["Its tabs  ·  pages", [], "1 - 4  ·  Q E", "LT RT  ·  LB RB"],
	["Straight to Gear  ·  Kindling", ["gear", "kindling"], "O  ·  K", ""], ["Straight to Journal  ·  Tasks", ["codex", "quest_log"], "J  ·  L", ""],
	["Settings", ["toggle_settings"], "", ""], ["Fullscreen", ["fullscreen"], "", "-"],
	["Colour grade", ["toggle_grade"], "", "-"], ["Stats overlay", ["toggle_debug"], "", "-"],
]


## the bindings are editable. Click a button, press the new key / mouse button (or controller button for the
## pad column); Esc cancels. A key or button that already does something else is refused, with the message below.
## Saved in settings.cfg (Settings.bindings) and applied by InputSetup on boot.
func _build_bindings(p: VBoxContainer) -> void:
	_bind_msg = _label("Click a button, then press the new key.", DIM, 15)
	_bind_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_bind_msg)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	p.add_child(head)
	var h0 := _label("", DIM, 15)
	h0.custom_minimum_size = Vector2(190, 0)
	head.add_child(h0)
	for t: String in ["Keyboard / mouse", "Controller"]:
		var hl := _label(t, DIM, 15)
		hl.custom_minimum_size = Vector2(158, 0)
		head.add_child(hl)
	for r: Array in InputSetup.REBINDABLE:
		var action: String = r[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		p.add_child(row)
		var a := _label(String(r[0]), QUIET, 16)
		a.custom_minimum_size = Vector2(190, 0)
		row.add_child(a)
		for slot: String in ["key", "pad"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(158, 30)
			b.clip_text = true
			_style_small(b, 15)
			var sl := slot
			b.pressed.connect(func() -> void: _begin_listen(action, sl))
			row.add_child(b)
			_bind_btns["%s|%s" % [action, slot]] = b
	var reset := Button.new()
	reset.text = "Reset Keys to Defaults"
	_style_small(reset, 16)
	reset.pressed.connect(func() -> void:
		InputSetup.reset_bindings()
		_listen = ""
		_refresh_binds()
		_bind_msg.text = "Keys and buttons are back to their defaults.")
	p.add_child(reset)
	_refresh_binds()


func _refresh_binds() -> void:
	for key: String in _bind_btns:
		var parts := key.split("|")
		var b: Button = _bind_btns[key]
		if key == _listen:
			b.text = "press a key..." if parts[1] == "key" else "press a button..."
			continue
		var ev: InputEvent = InputSetup.first_event(parts[0], parts[1])
		if ev != null:
			b.text = InputSetup.event_name(ev)
		else:
			b.text = _pad_text([parts[0]], "") if parts[1] == "pad" else "-"


func _begin_listen(action: String, slot: String) -> void:
	_listen = "%s|%s" % [action, slot]
	_listen_ms = Time.get_ticks_msec()
	_bind_msg.text = "Press the new %s for %s. Esc cancels." % ["key or mouse button" if slot == "key" else "controller button", InputSetup.label_of(action)]
	_refresh_binds()


## While a button waits for its binding every key, mouse button and pad button is its answer.
func _listen_input(event: InputEvent) -> void:
	var parts := _listen.split("|")
	var action: String = parts[0]
	var slot: String = parts[1]
	var ev: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_listen = ""
			_bind_msg.text = "Cancelled."
			_refresh_binds()
			get_viewport().set_input_as_handled()
			return
		if slot == "pad":
			_bind_msg.text = "That is a keyboard key. Press a controller button, or Esc."
			get_viewport().set_input_as_handled()
			return
		ev = event
	elif event is InputEventMouseButton and event.pressed and slot == "key" and Time.get_ticks_msec() - _listen_ms > 250 \
			and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		ev = event
	elif event is InputEventJoypadButton and event.pressed and slot == "pad":
		ev = event
	if ev == null:
		return
	get_viewport().set_input_as_handled()
	var copy: InputEvent
	if ev is InputEventKey:
		copy = InputEventKey.new()
		var code := (ev as InputEventKey).physical_keycode
		(copy as InputEventKey).physical_keycode = code if code != KEY_NONE else (ev as InputEventKey).keycode
	elif ev is InputEventMouseButton:
		copy = InputEventMouseButton.new()
		(copy as InputEventMouseButton).button_index = (ev as InputEventMouseButton).button_index
	else:
		copy = InputEventJoypadButton.new()
		(copy as InputEventJoypadButton).button_index = (ev as InputEventJoypadButton).button_index
	var why: String = InputSetup.rebind(action, slot, copy)
	if why == "":
		_bind_msg.text = "%s is now %s." % [InputSetup.label_of(action), InputSetup.event_name(copy)]
		_listen = ""
		UiSound.play(self, "confirm")
	else:
		_bind_msg.text = why + " Press another, or Esc."
		UiSound.play(self, "back")
	_refresh_binds()


func _keys_text(actions: Array, fallback: String) -> String:
	var parts := PackedStringArray()
	for act: String in actions:
		if not InputMap.has_action(act):
			continue
		var mine := PackedStringArray()
		for ev in InputMap.action_get_events(act):
			if ev is InputEventKey:
				var kc := (ev as InputEventKey).physical_keycode
				if kc == KEY_NONE:
					kc = (ev as InputEventKey).keycode
				mine.append(OS.get_keycode_string(kc))
			elif ev is InputEventMouseButton:
				mine.append(String({MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get((ev as InputEventMouseButton).button_index, "Mouse")))
		if not mine.is_empty():
			parts.append(" / ".join(mine))
	return fallback if parts.is_empty() else "  ·  ".join(parts)


const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right"}


func _pad_text(actions: Array, fallback: String) -> String:
	if fallback != "":
		return fallback
	var parts := PackedStringArray()
	for act: String in actions:
		if not InputMap.has_action(act):
			continue
		for ev in InputMap.action_get_events(act):
			if ev is InputEventJoypadButton:
				var bi := (ev as InputEventJoypadButton).button_index
				parts.append(String(PAD_NAMES.get(bi, "Button %d" % bi)))
				break
			if ev is InputEventJoypadMotion:
				var ax := (ev as InputEventJoypadMotion).axis
				parts.append("RT" if ax == JOY_AXIS_TRIGGER_RIGHT else ("LT" if ax == JOY_AXIS_TRIGGER_LEFT else "Stick"))
				break
	return "  ·  ".join(parts) if not parts.is_empty() else "-"


func _erase_lapse() -> void:
	if is_instance_valid(_erase_btn) and _erase_btn.text.begins_with("Confirm"):
		_erase_btn.text = "Erase Saved Progress"


## The hint line follows the focused control (pad / keys); the mouse uses the tooltips.
func _on_focus(c: Control) -> void:
	if _hint_line == null or not _root.visible or c == null or not _root.is_ancestor_of(c):
		return
	var tip := c.tooltip_text
	var n: Node = c
	while tip == "" and n.get_parent() is Control and n.get_parent() != _root:
		n = n.get_parent()
		tip = (n as Control).tooltip_text
	UiSound.play(self, "move")
	_hint_line.text = tip


func _footer() -> HBoxContainer:
	var f := HBoxContainer.new()
	f.alignment = BoxContainer.ALIGNMENT_CENTER
	f.add_theme_constant_override("separation", 20)
	var reset := Button.new()
	reset.text = "Reset to Defaults"
	_style_small(reset, 16)
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_refresh()
		Events.toast.emit("Settings reset to defaults"))
	f.add_child(reset)
	var erase := Button.new()
	_erase_btn = erase
	erase.text = "Erase Saved Progress"
	erase.tooltip_text = "Deletes the save and the Journal. The night you are in carries on as it is; the next launch starts from the beginning. Settings are kept."
	_style_small(erase, 16)
	erase.pressed.connect(func() -> void:           # two-step so a stray click cannot wipe a run
		if erase.text.begins_with("Confirm"):
			Travel.erase_save()
			erase.text = "Erased"
			erase.disabled = true
			# r35 B10: the session used to go on, silently never saving again. The run is over: back to the title.
			Events.toast.emit("Progress erased. Returning to the title.")
			get_tree().create_timer(0.8, true).timeout.connect(Travel.to_title)
		else:
			erase.text = "Confirm: erase everything?"
			# the confirm lapses by itself: a stray press later cannot finish what this one began
			get_tree().create_timer(4.0, true).timeout.connect(_erase_lapse))   # a method: no lambda capture to outlive the button
	f.add_child(erase)
	erase.visible = not on_title
	var quit_btn := Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.tooltip_text = "Saves and closes the game."
	_style_small(quit_btn, 16)
	quit_btn.pressed.connect(func() -> void:
		if quit_btn.text.begins_with("Really"):
			Settings.flush()
			Travel.save_now()
			Travel.leaving = true
			get_tree().quit()
		else:
			quit_btn.text = "Really quit?"
			get_tree().create_timer(3.0, true).timeout.connect(func() -> void:
				if is_instance_valid(quit_btn):
					quit_btn.text = "Quit Game"))
	f.add_child(quit_btn)
	var close_btn := Button.new()
	close_btn.text = "Close  (Esc)"
	_style_small(close_btn, 16)
	close_btn.pressed.connect(close)
	f.add_child(close_btn)
	return f


# --- builders -----------------------------------------------------------------

func _label(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _title(text: String, size: int, color: Color) -> Label:
	var l := _label(text, color, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _section(text: String) -> Label:
	return _label(text, LILAC, 17)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _style_small(c: Control, size := 16) -> void:
	c.add_theme_font_override("font", _font)
	c.add_theme_font_size_override("font_size", size)


## A labelled row; `hint` shows as a tooltip on the whole row.
func _row(p: VBoxContainer, label: String, hint: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.tooltip_text = hint
	row.mouse_entered.connect(func() -> void: _hint_line.text = hint)   # captures only a String
	p.add_child(row)
	var l := _label(label, QUIET, 18)
	l.custom_minimum_size = Vector2(220, 32)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.tooltip_text = hint
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(l)
	return row


func _check(p: VBoxContainer, label: String, hint: String, on_toggle: Callable) -> CheckButton:
	var cb := CheckButton.new()
	cb.tooltip_text = hint
	_row(p, label, hint).add_child(cb)
	cb.toggled.connect(func(v: bool) -> void:
		if not _refreshing:
			UiSound.play(self, "confirm")
			on_toggle.call(v))
	return cb


func _option(p: VBoxContainer, label: String, items: Array, hint: String, on_pick: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.tooltip_text = hint
	ob.custom_minimum_size = Vector2(220, 0)
	_style_small(ob)
	for it in items:
		ob.add_item(String(it))
	_row(p, label, hint).add_child(ob)
	ob.item_selected.connect(func(i: int) -> void:
		if not _refreshing:
			UiSound.play(self, "confirm")
			on_pick.call(i))
	return ob


func _slider(row: HBoxContainer, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(240, 24)
	s.value_changed.connect(func(_v: float) -> void:
		var now := Time.get_ticks_msec()
		if not _refreshing and now - _tick_ms > 45:      # a soft tick per step, not a buzz on a drag
			_tick_ms = now
			UiSound.play(self, "tick"))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	return s


func _value_label(row: HBoxContainer) -> Label:
	var l := _label("", QUIET, 16)
	l.custom_minimum_size = Vector2(64, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)
	return l


# --- state -------------------------------------------------------------------

## A hand-changed graphics option: apply it and show the preset as Custom (or a preset it matches).
func _custom() -> void:
	var m := Settings.matching_preset()
	if m >= 0:
		Settings.quality_preset = m
	Settings.apply()
	_preset_option.select(m if m >= 0 else Settings.PRESET_NAMES.size())


func _refresh() -> void:
	_refreshing = true
	_fullscreen_btn.button_pressed = Settings.fullscreen
	_res_option.select(Settings.window_size_index)
	_res_option.disabled = Settings.fullscreen
	_vsync_btn.button_pressed = Settings.vsync
	_monitor_option.clear()
	_monitor_option.add_item("Automatic")
	for i in DisplayServer.get_screen_count():
		_monitor_option.add_item(Settings.screen_name(i))
	_monitor_option.select(clampi(Settings.monitor + 1, 0, _monitor_option.item_count - 1))
	_fps_option.clear()
	for v: int in Settings.FPS_CHOICES:
		_fps_option.add_item(Settings.fps_choice_name(v))
	var fi := Settings.FPS_CHOICES.find(Settings.fps_limit)
	if fi < 0:
		_fps_option.add_item(str(Settings.fps_limit))      # a hand-edited value: show it as it is
		fi = _fps_option.item_count - 1
	_fps_option.select(fi)
	_native_btn.button_pressed = Settings.native_output
	_pace_note.text = _pace_text()
	var m := Settings.matching_preset()
	_preset_option.select(m if m >= 0 else Settings.PRESET_NAMES.size())
	var auto := Settings.render_scale <= 0.0
	_scale_auto_btn.button_pressed = auto
	_scale_slider.editable = not auto
	_scale_slider.value = 1.0 if auto else Settings.render_scale
	_scale_label.text = "Auto" if auto else "%d%%" % roundi(Settings.render_scale * 100.0)
	_shadow_option.select(Settings.shadow_quality)
	_fog_btn.button_pressed = Settings.fog_enabled
	_ssao_btn.button_pressed = Settings.ssao_enabled
	_glow_btn.button_pressed = Settings.glow_enabled
	_grade_btn.button_pressed = Settings.grade_enabled
	_ssr_btn.button_pressed = Settings.ssr_enabled
	_blur_slider.value = Settings.motion_blur
	_aa_option.select(Settings.aa_mode)
	_blur_label.text = "Off" if Settings.motion_blur <= 0.001 else "%d%%" % roundi(Settings.motion_blur * 100.0)
	for field: String in _vol:
		var v := float(Settings.get(field))
		(_vol[field][0] as HSlider).value = v
		(_vol[field][1] as Label).text = "Off" if v <= 0.001 else "%d%%" % roundi(v * 100.0)
	_fov_slider.value = Settings.fov
	_fov_label.text = "%d°" % int(Settings.fov)
	_sens_slider.value = Settings.mouse_sensitivity
	_sens_label.text = "%.1f" % (Settings.mouse_sensitivity / 0.0025 * 5.0)
	_stick_slider.value = Settings.stick_sensitivity
	_stick_label.text = "%.1f" % (Settings.stick_sensitivity / 2.6 * 5.0)
	_invert_btn.button_pressed = Settings.invert_y
	if not _bind_btns.is_empty():
		_refresh_binds()
	_tscale_slider.value = Settings.text_scale
	_tscale_label.text = "%d%%" % roundi(Settings.text_scale * 100.0)
	_refreshing = false


## What the player will actually get, in words: the screen, its rate, and the cap that applies.
func _pace_text() -> String:
	var hz := Settings.refresh_hz()
	var cap := Settings.effective_max_fps()
	var on := "Display %d · %d Hz" % [Settings.current_screen() + 1, hz]
	var win := get_window().size
	if Settings.native_output and win.y > int(Settings.OUTPUT_BASE.y * 1.15):
		on += ". Full-Res Output renders %d x %d: expect far lower fps (V-Sync then halves it)" % [win.x, win.y]
	if cap == 0:
		return "%s. Uncapped: macOS still shows at most %d frames a second here." % [on, hz]
	# a fixed-refresh screen (not the MacBook's ProMotion) can only show refresh/1, /2, /3 with
	# V-Sync: a frame over 1000/hz ms waits for the next refresh (144 Hz -> 72 fps)
	var fixed := "" if hz <= 120 else " A frame slower than %.1f ms waits a whole extra refresh (%d fps): turn on Variable refresh for this monitor in macOS Displays settings, or turn V-Sync off." % [1000.0 / hz, hz / 2]
	if Settings.vsync and cap >= hz:
		return "%s. V-Sync: up to %d fps, no tearing.%s" % [on, cap, fixed]
	if Settings.vsync:
		return "%s. V-Sync, capped at %d fps.%s" % [on, cap, fixed]
	return "%s. Capped at %d fps (V-Sync off: may tear)." % [on, cap]


## Re-read the display state a few frames after a change (a monitor move lands asynchronously).
func _later_refresh() -> void:
	for _i in 8:
		await get_tree().process_frame
	if is_inside_tree() and _root.visible:
		_refresh()


func _show_tab(i: int) -> void:
	if _root.visible and i != _tab:
		UiSound.play(self, "tab")
	_tab = i
	for k in _pages.size():
		_pages[k].visible = k == i
		_tab_btns[k].set_pressed_no_signal(k == i)
	if _root.visible:
		_focus_first(_pages[i])


## Keyboard / pad: focus the page's first control so arrows and A work straight away.
func _focus_first(n: Node) -> bool:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c is BaseButton or c is Range):
			(c as Control).grab_focus()
			return true
		if _focus_first(c):
			return true
	return false


## Panel fits the window: 720 x up to 640 of tab content, smaller on small windows.
func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var h := clampf(vs.y - 330.0, 240.0, 440.0)          # title, tabs, hint line and footer take ~330
	(_pages[0].get_parent() as Control).custom_minimum_size = Vector2(minf(680.0, vs.x - 120.0), h)


# --- open / close ------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _listen != "" and _root.visible:
		_listen_input(event)
		return
	if event.is_action_pressed("toggle_settings"):
		if not _root.visible and get_tree().paused and event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			return            # Esc over an open Kindling / Journal / shop closes that menu (each has
			                  # its own Esc), it does not stack Settings on top; F2 / Start still open it
		if _root.visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _root.visible and (event.is_action_pressed("release_mouse") or (event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"))):
		close()
		get_viewport().set_input_as_handled()
	elif _root.visible and event is InputEventKey and event.pressed and not event.echo:
		# Q / E (and the bumpers) flip tabs
		if (event as InputEventKey).physical_keycode == KEY_Q:
			_show_tab((_tab + TABS.size() - 1) % TABS.size())
			get_viewport().set_input_as_handled()
		elif (event as InputEventKey).physical_keycode == KEY_E:
			_show_tab((_tab + 1) % TABS.size())
			get_viewport().set_input_as_handled()
	elif _root.visible and event is InputEventJoypadButton and event.pressed:
		var jb := (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_LEFT_SHOULDER or jb == JOY_BUTTON_RIGHT_SHOULDER:
			_show_tab((_tab + (1 if jb == JOY_BUTTON_RIGHT_SHOULDER else TABS.size() - 1)) % TABS.size())
			get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	_root.visible = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_was_paused = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true   # the shade used to keep hunting while the menu was up
	_hint_line.text = ""
	UiSound.play(self, "confirm")
	_focus_first(_pages[_tab])


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	_listen = ""
	UiSound.play(self, "back")
	Settings.flush()          # write out whatever the debounce is still holding
	# opened over the Kindling, a dialogue, the shop or the Journal (each pauses the world): leave
	# the world paused for them. Unpausing here let the night run on behind an open menu.
	get_tree().paused = _was_paused
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().gui_release_focus()

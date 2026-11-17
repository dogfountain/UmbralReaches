extends Node
## Persistent graphics/video/camera settings (user://settings.cfg). Pure data + persistence --
## ui/settings_menu.gd edits these fields and calls save(); world/main.gd listens for `changed`
## and actually applies them to the live scene (window, environment, lights, camera).

signal changed
## The player switched between keyboard/mouse and a pad (prompts show that device's buttons).
signal input_device_changed(pad: bool)

## user://settings.cfg, or the scratch folder given by `-- --save-dir=` (core/util/save_dir.gd).
var PATH: String = preload("res://core/util/save_dir.gd").path("settings.cfg")
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const SHADOW_NAMES := ["Off", "Low", "High"]
const PRESET_NAMES := ["Performance", "Balanced", "Cinematic"]
## Frame rate limit choices: -1 = match the display the game is on, 0 = unlimited, else fps.
const FPS_CHOICES := [-1, 0, 30, 60, 72, 90, 120, 144, 165, 240]
const _OLD_FPS_LIMITS := [0, 30, 60, 120, 144]   ## the pre-r25 fps_limit_index table (migration)
## Final-image size on 4K / Retina screens. The 3D is already capped at render_height_cap() rows,
## so rendering the whole frame (post, grade, UI) at 4K only cost GPU: on Luke's 144 Hz AOC
## (macOS reports it as 3840x2160) fullscreen ran 60-70 fps, GPU-bound, and V-Sync showed 72.
const OUTPUT_BASE := Vector2i(1920, 1080)
## Anti-aliasing choices (Zone._apply_aa). Not part of the quality presets.
const AA_NAMES := ["Off", "FXAA (fast, soft)", "SMAA (sharper edges)", "TAA (smoothest, slight ghosting)", "MSAA 2x (geometry edges)", "MSAA 4x (geometry edges, costly)"]
const SAVE_DELAY := 0.75        # seconds of quiet before the file is actually written

var using_pad := false              ## the last input came from a pad (not saved; set by _input)
var _save_timer := 0.0
var _save_pending := false
var _emit_queued := false

var fullscreen := false
var window_size_index := 1          # index into WINDOW_SIZES
var vsync := true
var render_scale := 0.0             # 0 = auto, else 0.5-1.0 fixed
var shadow_quality := 2             # 0 off, 1 low, 2 high
var fog_enabled := true
var glow_enabled := true
var night_life := true              ## the living night (core/world/night_life): moon course, eclipse, living windows, far light signatures, moths, mist
var grade_enabled := true
var dof_enabled := false            ## kept for old cfg files; far DoF stays off (binding rule)
var ssr_enabled := false
var motion_blur := 0.25             ## 0 off .. 1; "a little" by default
var aa_mode := 0                    ## index into AA_NAMES; 0 = off (the crisp look Luke chose)
var fps_limit := -1                 ## see FPS_CHOICES: -1 match display, 0 unlimited, else fps
var monitor := -1                   ## screen index to show the game on; -1 = wherever macOS opens it
var native_output := false          ## true: final image at the screen's full pixel count (4K/Retina)
var invert_y := false
var bindings: Dictionary = {}       ## the player's own key / button bindings: action -> {"key": {t, c}, "pad": {t, c}} (autoload/input_setup.gd)
var text_scale := 1.0               ## 0.85-1.5: the HUD's running text (ui/text_director.gd px())
var quality_preset := 1             # 0 Performance, 1 Balanced, 2 Cinematic
var detail := 1                     ## world detail 0 low .. 2 high: mesh LOD distance, undergrowth density
                                    ## and range, shadow casters, internal height (set by the presets)
var fov := 54.0
var mouse_sensitivity := 0.0025
var stick_sensitivity := 2.6        ## pad right stick, rad/s at full tilt (Player.stick_sensitivity)
var master_volume := 0.9            # linear 0..1, per bus (see apply_audio)
var sfx_volume := 0.85
var ambience_volume := 0.7
var music_volume := 0.7             ## the generative night music (scape_music.gd) on its own bus
var voices_volume := 0.9            ## the creatures' and bosses' voices (the Voices bus, under Effects)
var ui_volume := 0.8                ## every interface cue (the UI bus, under Effects)
var world_volume := 0.9            ## the world's own sounds the rework added (doors, chests, pickups, fires, small life; the World bus, under Effects)
var combat_volume := 0.9           ## the combat layer (hurts, parries, schools, tells; the Combat bus, under Effects)
var stingers_volume := 0.85        ## stingers, boss intros and deaths, the eclipse, the camp (the Stingers bus)
var score_intensity := 0.8          ## the dynamic score's stems (the Score bus, under Music): tension, combat, aftermath, the acts' beds
const BUSES := ["SFX", "Ambience", "Music"]
const SUB_BUSES := {"UI": "SFX", "Score": "Music", "World": "SFX", "Combat": "SFX", "Stingers": "Master"}        ## created here, sent to their parent bus (Voices is made by Ambience)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the debounce keeps ticking while the menu pauses the world
	load_settings()
	InputSetup.apply_overrides(bindings)       # InputSetup is ready first (it defines the defaults); the player's own go over them
	_ensure_buses()
	apply_audio()
	changed.connect(apply_audio)
	set_process(false)


func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 6.0):
		pad = false
	if pad != using_pad:
		using_pad = pad
		input_device_changed.emit(pad)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		if FileAccess.file_exists(PATH):
			push_warning("Settings: %s is unreadable; using defaults (it is rewritten on the next change)" % PATH)
		return
	# every value is type- and range-checked: a hand-edited or damaged file falls back per field
	# instead of a script error (a String in a float field) or an out-of-range index into a table
	# literal defaults on type failure: never keep a prior bad value as the fallback (robust_test)
	fullscreen = _v(cfg, "display", "fullscreen", false)
	window_size_index = clampi(_v(cfg, "display", "window_size_index", 1), 0, WINDOW_SIZES.size() - 1)
	vsync = _v(cfg, "display", "vsync", true)
	render_scale = _v(cfg, "graphics", "render_scale", render_scale)
	render_scale = 0.0 if render_scale <= 0.0 else clampf(render_scale, 0.5, 1.0)
	shadow_quality = clampi(_v(cfg, "graphics", "shadow_quality", shadow_quality), 0, SHADOW_NAMES.size() - 1)
	fog_enabled = _v(cfg, "graphics", "fog_enabled", fog_enabled)
	glow_enabled = _v(cfg, "graphics", "glow_enabled", glow_enabled)
	night_life = _v(cfg, "graphics", "night_life", night_life)
	grade_enabled = _v(cfg, "graphics", "grade_enabled", grade_enabled)
	ssr_enabled = _v(cfg, "graphics", "ssr_enabled", ssr_enabled)
	quality_preset = clampi(_v(cfg, "graphics", "quality_preset", quality_preset), 0, PRESETS.size() - 1)
	detail = clampi(_v(cfg, "graphics", "detail", int(PRESETS[quality_preset][6])), 0, 2)
	motion_blur = clampf(_v(cfg, "graphics", "motion_blur", motion_blur), 0.0, 1.0)
	aa_mode = clampi(_v(cfg, "graphics", "aa_mode", aa_mode), 0, AA_NAMES.size() - 1)
	if cfg.has_section_key("display", "fps_limit"):
		fps_limit = _v(cfg, "display", "fps_limit", fps_limit)
		fps_limit = -1 if fps_limit < 0 else (0 if fps_limit == 0 else clampi(fps_limit, 20, 1000))
	elif cfg.has_section_key("display", "fps_limit_index"):
		fps_limit = int(_OLD_FPS_LIMITS[clampi(_v(cfg, "display", "fps_limit_index", 0), 0, _OLD_FPS_LIMITS.size() - 1)])
	monitor = maxi(-1, _v(cfg, "display", "monitor", monitor))
	native_output = _v(cfg, "display", "native_output", native_output)
	invert_y = _v(cfg, "camera", "invert_y", invert_y)
	dof_enabled = false
	text_scale = clampf(_v(cfg, "hud", "text_scale", text_scale), 0.85, 1.5)
	fov = clampf(_v(cfg, "camera", "fov", fov), 50.0, 90.0)
	mouse_sensitivity = clampf(_v(cfg, "camera", "mouse_sensitivity", mouse_sensitivity), 0.0005, 0.01)
	stick_sensitivity = clampf(_v(cfg, "camera", "stick_sensitivity", stick_sensitivity), 1.0, 5.0)
	master_volume = clampf(_v(cfg, "audio", "master", master_volume), 0.0, 1.0)
	sfx_volume = clampf(_v(cfg, "audio", "sfx", sfx_volume), 0.0, 1.0)
	ambience_volume = clampf(_v(cfg, "audio", "ambience", ambience_volume), 0.0, 1.0)
	music_volume = clampf(_v(cfg, "audio", "music", music_volume), 0.0, 1.0)
	voices_volume = clampf(_v(cfg, "audio", "voices", voices_volume), 0.0, 1.0)
	ui_volume = clampf(_v(cfg, "audio", "ui", ui_volume), 0.0, 1.0)
	score_intensity = clampf(_v(cfg, "audio", "score", score_intensity), 0.0, 1.0)
	world_volume = clampf(_v(cfg, "audio", "world", world_volume), 0.0, 1.0)
	combat_volume = clampf(_v(cfg, "audio", "combat", combat_volume), 0.0, 1.0)
	stingers_volume = clampf(_v(cfg, "audio", "stingers", stingers_volume), 0.0, 1.0)
	bindings = _clean_bindings(cfg.get_value("input", "bindings", {}))
	var mp := matching_preset()       # the saved fields win over the stored index: a file that matches no preset is Custom
	if mp >= 0:
		quality_preset = mp


## Saved bindings kept only if they have the right shape: action -> {"key"|"pad": {"t": String, "c": int}}.
func _clean_bindings(v: Variant) -> Dictionary:
	var out := {}
	if not (v is Dictionary):
		return out
	for action in v:
		if not (action is String) or not ((v[action]) is Dictionary):
			continue
		var mine := {}
		for slot in ["key", "pad"]:
			var d: Variant = (v[action] as Dictionary).get(slot)
			if d is Dictionary and (d as Dictionary).get("t") is String and ((d as Dictionary).get("c") is int):
				mine[slot] = {"t": String(d.t), "c": int(d.c)}
		if not mine.is_empty():
			out[String(action)] = mine
	return out


## A value from the file if it has the default's type (int and float interchange, NaN refused),
## else the default.
func _v(cfg: ConfigFile, section: String, key: String, def: Variant) -> Variant:
	var v: Variant = cfg.get_value(section, key, def)
	match typeof(def):
		TYPE_BOOL:
			return v if v is bool else def
		TYPE_INT:
			if v is int or (v is float and is_finite(v)):
				return int(v)
			return def
		TYPE_FLOAT:
			if (v is float and is_finite(v)) or v is int:
				return float(v)
			return def
	return v if typeof(v) == typeof(def) else def


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "window_size_index", window_size_index)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("graphics", "render_scale", render_scale)
	cfg.set_value("graphics", "shadow_quality", shadow_quality)
	cfg.set_value("graphics", "fog_enabled", fog_enabled)
	cfg.set_value("graphics", "glow_enabled", glow_enabled)
	cfg.set_value("graphics", "night_life", night_life)
	cfg.set_value("graphics", "grade_enabled", grade_enabled)
	cfg.set_value("graphics", "dof_enabled", dof_enabled)
	cfg.set_value("graphics", "ssr_enabled", ssr_enabled)
	cfg.set_value("graphics", "quality_preset", quality_preset)
	cfg.set_value("graphics", "detail", detail)
	cfg.set_value("graphics", "motion_blur", motion_blur)
	cfg.set_value("graphics", "aa_mode", aa_mode)
	cfg.set_value("display", "fps_limit", fps_limit)
	cfg.set_value("display", "monitor", monitor)
	cfg.set_value("display", "native_output", native_output)
	cfg.set_value("camera", "invert_y", invert_y)
	cfg.set_value("hud", "text_scale", text_scale)
	cfg.set_value("camera", "fov", fov)
	cfg.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("camera", "stick_sensitivity", stick_sensitivity)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "voices", voices_volume)
	cfg.set_value("audio", "ui", ui_volume)
	cfg.set_value("audio", "score", score_intensity)
	cfg.set_value("audio", "world", world_volume)
	cfg.set_value("audio", "combat", combat_volume)
	cfg.set_value("audio", "stingers", stingers_volume)
	cfg.set_value("input", "bindings", bindings)
	# write a temp file and rename it over the old one: quitting mid-write never leaves half a file
	var tmp := PATH + ".tmp"
	if cfg.save(tmp) != OK:
		push_warning("Settings: could not write %s" % tmp)
		return
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))
	if err != OK:
		push_warning("Settings: could not replace %s (%s)" % [PATH, err])


## The buses are laid out in default_bus_layout.tres (Master with a gentle compressor and a hard limiter; SFX, Ambience, Music; Score, World, Combat,
## Voices, UI and Stingers under them; AmbOut). This only adds any the file lacks (an old layout, a test harness), so every setting still maps.
func _ensure_buses() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for b2: String in SUB_BUSES:
		if AudioServer.get_bus_index(b2) == -1:
			AudioServer.add_bus()
			var j := AudioServer.bus_count - 1
			AudioServer.set_bus_name(j, b2)
			AudioServer.set_bus_send(j, String(SUB_BUSES[b2]))


func apply_audio() -> void:
	var vols := {"Master": master_volume, "SFX": sfx_volume, "Ambience": ambience_volume, "Music": music_volume, "Voices": voices_volume, "UI": ui_volume, "Score": score_intensity, "World": world_volume, "Combat": combat_volume, "Stingers": stingers_volume}
	for b: String in vols:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			var v: float = vols[b]
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(i, v <= 0.001)


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
	if not bindings.is_empty():
		InputSetup.reset_bindings()
	fullscreen = false
	window_size_index = 1
	vsync = true
	render_scale = 0.0
	fps_limit = -1
	monitor = -1
	native_output = false
	aa_mode = 0
	fov = 54.0
	mouse_sensitivity = 0.0025
	stick_sensitivity = 2.6
	invert_y = false
	text_scale = 1.0
	master_volume = 0.9
	sfx_volume = 0.85
	ambience_volume = 0.7
	music_volume = 0.7
	voices_volume = 0.9
	ui_volume = 0.8
	score_intensity = 0.8
	world_volume = 0.9
	combat_volume = 0.9
	stingers_volume = 0.85
	apply_preset(1)


# --- display: monitors, pacing ---------------------------------------------------------------

## The screen the game window is on now (DisplayServer index).
func current_screen() -> int:
	return DisplayServer.window_get_current_screen() if DisplayServer.get_name() != "headless" else 0


## Refresh rate of `screen` (default: the game's screen), rounded; 60 when the OS won't say.
func refresh_hz(screen := -1) -> int:
	var s := current_screen() if screen < 0 else screen
	var hz := DisplayServer.screen_get_refresh_rate(s)
	return roundi(hz) if hz > 1.0 else 60


## Engine.max_fps for the current choice. "Match display" is the screen's own rate. With V-Sync on,
## a limit at or above the refresh rate is set to the refresh rate itself: measured on the AOC,
## vsync + max_fps 144 held 144.7 fps where vsync + unlimited wandered at 127-133.
func effective_max_fps() -> int:
	var hz := refresh_hz()
	var lim := hz if fps_limit < 0 else fps_limit
	if vsync and (lim == 0 or lim > hz):
		lim = hz
	return lim


## Menu label for a limit choice, e.g. "Match Display (144 Hz)".
func fps_choice_name(v: int) -> String:
	if v < 0:
		return "Match Display (%d Hz)" % refresh_hz()
	if v == 0:
		return "Unlimited"
	return str(v)


## Menu label for a screen, e.g. "Display 2 · 1920 x 1080 · 144 Hz".
func screen_name(i: int) -> String:
	var sz := DisplayServer.screen_get_size(i)
	var sc := maxf(DisplayServer.screen_get_scale(i), 1.0)
	var tag := " (main)" if i == DisplayServer.get_primary_screen() else ""
	return "Display %d%s · %d x %d · %d Hz" % [i + 1, tag, roundi(sz.x / sc), roundi(sz.y / sc), refresh_hz(i)]


## Internal render height. A 1440-tall buffer is ~2300px wide on this panel, and cinematic
## (fog, SSAO, glow, depth of field, SSR) cannot hold 120Hz there. 960 keeps those effects on.
## Low world detail (the Performance preset) renders 810 rows: about 30 % fewer pixels, and the
## frame is mostly fill (perf_tour --attrib: half the pixels saves ~2.5 of ~7 ms).
func render_height_cap() -> int:
	return 810 if detail <= 0 else 960


## What each preset sets: [shadows, fog, glow, grade, ssr, motion blur, detail] (ambient occlusion is out of the game:
## Luke, 14 Nov; it was 0.6 ms of a fight frame for creases that barely showed at night)
const PRESETS := [
	[1, false, true, true, false, 0.0, 0],
	[2, true, true, true, false, 0.25, 1],
	[2, true, true, true, true, 0.35, 2],
]


func apply_preset(index: int) -> void:
	set_preset_fields(index)
	apply()


## The preset's fields only, nothing pushed or saved (perf tools set a preset in memory with this).
func set_preset_fields(index: int) -> void:
	quality_preset = clampi(index, 0, 2)
	var p: Array = PRESETS[quality_preset]
	shadow_quality = p[0]
	fog_enabled = p[1]
	glow_enabled = p[2]
	grade_enabled = p[3]
	ssr_enabled = p[4]
	motion_blur = p[5]
	detail = p[6]
	dof_enabled = false


## The preset the current graphics options match, or -1 ("Custom") once any one was changed.
func matching_preset() -> int:
	for i in PRESETS.size():
		var p: Array = PRESETS[i]
		if shadow_quality == p[0] and fog_enabled == p[1] and glow_enabled == p[2] \
				and grade_enabled == p[3] and ssr_enabled == p[4] and is_equal_approx(motion_blur, p[5]) and detail == p[6]:
			return i
	return -1

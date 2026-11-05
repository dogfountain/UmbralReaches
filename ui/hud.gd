extends CanvasLayer
## HUD: Gloom meter, interaction prompt, toasts, zone title card, controls hint, debug stats, Hollowed fade.
## Built in code so layout stays in one file; the base canvas is 1920x1080 and scales with the window.
## r33 (after WoW's interface): the Gloom meter lives in the wanderer's unit frame now (ui/unit_frames.gd,
## with the target and boss frames and the cast bar), floating combat text (ui/combat_text.gd) and
## an XP strip (ui/xp_bar.gd, only once XP exists). The plain bar stays as the fallback when the
## frames are switched off in settings. The controls card is a first-minutes hint, once per save,
## and the settings menu can bring it back (show_card()).

const LILAC := Color("#A98BFF")
const LANTERN := Color("#FFB347")
const EMBER := Color("#FF5A1F")
const VOID := Color("#05040D")
const QUIET := Color(0.72, 0.74, 0.86, 0.85)

const BAKE_INFO := "res://world/zones/ascension/bake_info.gd"
const BOOT_DIAG := preload("res://core/debug/boot_diag.gd")

var _font: Font
var _build_line := ""
var _bench_line := ""
var _bar: GloomBar
var _prompt: Label
var _toast: Label
var _title: Label
var _subtitle: Label
var _hint: Label
var _debug: Label
var _fade: ColorRect
var _toast_tw: Tween
var _prompt_tw: Tween
var _debug_t := 0.0
var _measure_rid: RID
# r29 (critique B): the first minutes. The title card and the controls used to play out under the
# loading screen (title gone, hint half faded by the time the night shows); the hint was one 200-
# character keyboard-only line that ran under the objectives and stayed up over every menu.
const CARD_TIME := 20.0
var _pad := false                 ## the last input came from a gamepad: the card and tips use pad names
var _seen_capture := false        ## the mouse has been captured once (menus free it: a "menu open" cue)
var _card_t := -1.0               ## seconds the controls card has been up; -1 not started yet
var _card_a := 0.0
var _life := 0.0
var _tip: Label
var _tip_tw: Tween
var _tips_done := {}
var _lessons: Array[String] = []        ## combat lessons waiting for the tip line (lesson())
var _tip_check := 0.0
var _sprint_t := 0.0
var _toast_q: Array[String] = []
var _toast_busy := false
var _aim: Control
var _gloom_label: Label
var _card_req := 0
const HudPrefs := preload("res://ui/hud_prefs.gd")
const Hints := preload("res://ui/hints.gd")


class Crosshair extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var col := Color(0.92, 0.88, 1.0, 0.78)
		var dim := Color(0.04, 0.03, 0.08, 0.45)
		var gap := 5.0
		var arm := 8.0
		var ends: Array[Vector2] = [
			Vector2(-gap - arm, 0.0), Vector2(-gap, 0.0),
			Vector2(gap, 0.0), Vector2(gap + arm, 0.0),
			Vector2(0.0, -gap - arm), Vector2(0.0, -gap),
			Vector2(0.0, gap), Vector2(0.0, gap + arm),
		]
		for i in range(0, ends.size(), 2):
			draw_line(c + ends[i], c + ends[i + 1], dim, 3.2)
			draw_line(c + ends[i], c + ends[i + 1], col, 1.5)
		draw_circle(c, 2.1, dim)
		draw_circle(c, 1.15, col)


class GloomBar extends Control:
	var value := 0.0
	var pulse := 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.02, 0.016, 0.05, 0.7))
		var t := value
		var fill := Color("#A98BFF").lerp(Color("#FF5A1F"), smoothstep(0.5, 1.0, t))
		if t > 0.75:
			fill = fill.lightened(0.25 * (0.5 + 0.5 * sin(pulse * 9.0)))
		draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4.0) * t, size.y - 4.0)), fill)
		for i in range(1, 4):   # quarter ticks
			var x := size.x * i / 4.0
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0, 0, 0, 0.6), 2.0)
		draw_rect(r, Color(0.66, 0.55, 1.0, 0.45), false, 2.0)


func _ready() -> void:
	layer = 10
	add_to_group(&"hud")                         # ui/hints.gd finds the tip line here
	process_mode = Node.PROCESS_MODE_ALWAYS     # the card and the crosshair step aside while the tree is paused
	_font = load("res://ui/fonts/Cinzel.ttf")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	HudPrefs.ensure()
	_card_req = HudPrefs.card_request
	var gl := _label(root, "GLOOM", 22, QUIET)
	gl.position = Vector2(48, 36)
	_gloom_label = gl
	_bar = GloomBar.new()
	_bar.position = Vector2(48, 72)
	_bar.size = Vector2(380, 16)
	root.add_child(_bar)

	_prompt = _label(root, "", 30, LANTERN, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -240          # r33: over the player's cast bar (which sits over the hotbar)
	_prompt.offset_bottom = -206
	_prompt.offset_left = -500
	_prompt.offset_right = 500
	_prompt.modulate.a = 0.0

	_toast = _label(root, "", 26, Color(0.85, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 196            # r33: under the target frame (it sits under the compass)
	_toast.offset_bottom = 236
	_toast.offset_left = -700
	_toast.offset_right = 700
	_toast.modulate.a = 0.0

	_title = _label(root, "", 64, Color(0.92, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 250
	_title.offset_bottom = 340
	_title.offset_left = -900
	_title.offset_right = 900
	_subtitle = _label(root, "", 26, LILAC, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_subtitle.offset_top = 340
	_subtitle.offset_bottom = 380
	_subtitle.offset_left = -900
	_subtitle.offset_right = 900
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	Events.zone_entered.connect(_on_zone)

	_hint = _label(root, "", 18, QUIET)
	_hint.position = Vector2(26, 196)  # r33: under the wanderer's frame and its buff row
	_hint.add_theme_constant_override("line_spacing", 4)
	# r30: body serif, on a dark backing plate (it sat straight on the bright sky)
	_hint.add_theme_font_override("font", preload("res://ui/type.gd").body())
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.02, 0.025, 0.04, 0.42)
	plate.set_corner_radius_all(6)
	plate.content_margin_left = 16
	plate.content_margin_right = 16
	plate.content_margin_top = 10
	plate.content_margin_bottom = 10
	_hint.add_theme_stylebox_override("normal", plate)
	_hint.modulate.a = 0.0
	if "using_pad" in Settings:
		_pad = bool(Settings.get("using_pad"))
	if Settings.has_signal("input_device_changed"):
		Settings.connect("input_device_changed", _on_device)
	_hint.text = _card_text()
	_tip = _label(root, "", 24, Color(0.88, 0.86, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_tip.add_theme_font_override("font", preload("res://ui/type.gd").body())
	_tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tip.offset_top = -334             # r33 merge: above the dialogue subtitle band (ui/dialogue.gd _sub, -290..-230)
	_tip.offset_bottom = -298
	_tip.offset_left = -700
	_tip.offset_right = 700
	_tip.modulate.a = 0.0

	var bar := Hotbar.new()
	bar.name = "Hotbar"
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_top = -136
	bar.offset_bottom = -30
	root.add_child(bar)
	root.add_child(load("res://core/story/objective_line.gd").new())   # objective lines (core/story, story agent)
	root.add_child(load("res://ui/compass.gd").new())                  # heading strip + beacon/brazier markers (ENS art pass)
	root.add_child(load("res://ui/minimap.gd").new())                  # round minimap, bottom right; M: near / wide / off (r32)
	root.add_child(load("res://ui/xp_bar.gd").new())                   # r33: XP strip along the bottom, once XP exists
	root.add_child(load("res://ui/unit_frames.gd").new())              # r33: player / target / boss frames, cast bar
	root.add_child(load("res://ui/combat_text.gd").new())              # r33: the wanderer's side of a fight, as text

	_debug = _label(root, "", 18, QUIET, HORIZONTAL_ALIGNMENT_RIGHT)
	_debug.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_debug.offset_left = -520
	_debug.offset_right = -40
	_debug.offset_top = 32
	_debug.offset_bottom = 380
	_debug.visible = false
	_debug.add_theme_font_override("font", ThemeDB.fallback_font)
	# Which build is this? Version from project settings, bake time from the generated stamp.
	var baked := "unbaked"
	if ResourceLoader.exists(BAKE_INFO):
		baked = load(BAKE_INFO).STAMP
	_build_line = "v%s  ·  baked %s" % [ProjectSettings.get_setting("application/config/version", "?"), baked]

	var aim := Crosshair.new()
	_aim = aim
	aim.name = "Crosshair"
	aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aim.offset_left = -24
	aim.offset_top = -24
	aim.offset_right = 24
	aim.offset_bottom = 24
	root.add_child(aim)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	Events.gloom_changed.connect(_on_gloom)
	Events.interact_hint.connect(_on_hint)
	Events.toast.connect(_on_toast)
	Events.hollowed.connect(_on_hollowed)
	Events.respawned.connect(_on_respawned)
	Events.benchmark_done.connect(func(summary: String) -> void: _bench_line = "BENCH  " + summary)
	_measure_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_measure_rid, true)


func _label(parent: Control, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug.visible = not _debug.visible
		_debug_t = 1.0
		get_viewport().set_input_as_handled()


## The device in hand (Settings tracks it: F, r29): the card and the tips name its buttons.
func _on_device(pad: bool) -> void:
	if pad != _pad:
		_pad = pad
		_hint.text = _card_text()


func _process(delta: float) -> void:
	var legacy := not HudPrefs.unit_frames     # r33: the frames carry the Gloom; the old bar is the fallback
	_bar.visible = legacy
	_gloom_label.visible = legacy
	if HudPrefs.card_request != _card_req:
		_card_req = HudPrefs.card_request
		show_card()
	_bar.pulse += delta
	if _bar.value > 0.75 or not is_equal_approx(_bar.value, _bar.get_meta("drawn", -1.0)):
		_bar.set_meta("drawn", _bar.value)
		_bar.queue_redraw()                  # only the pulse (or a change) needs a redraw
	_life += delta
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_seen_capture = true
	_card_tick(delta)
	_tips_tick(delta)
	if _aim:
		_aim.visible = not _menu_open()          # no crosshair over a conversation or a menu
	if not _debug.visible:
		return
	_debug_t += delta
	if _debug_t < 0.25:
		return
	_debug_t = 0.0
	_refresh_debug()


func _refresh_debug() -> void:
	var vp := get_viewport()
	var win := get_window().size
	var scale_3d := vp.scaling_3d_scale
	var out := Vector2(win)
	if get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		out = vp.get_visible_rect().size     # the reduced output on 4K / Retina (Zone._apply_output)
	var buf := Vector2i(roundi(out.x * scale_3d), roundi(out.y * scale_3d))
	var fps := maxi(Engine.get_frames_per_second(), 1)
	var diag: String = BOOT_DIAG.summary if BOOT_DIAG != null else "diag script missing"
	_debug.text = "%d fps  ·  frame %.1f ms\nGPU %.2f ms  ·  render CPU %.2f ms\nprocess %.2f ms  ·  physics %.2f ms\n%d draw calls  ·  %s primitives\n3D %dx%d @ %d%%  ·  window %dx%d\n%d light zones\n%s  ·  %s\n%s\n%s\n%s" % [
		fps,
		1000.0 / float(fps),
		RenderingServer.viewport_get_measured_render_time_gpu(_measure_rid),
		RenderingServer.viewport_get_measured_render_time_cpu(_measure_rid),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		String.num_int64(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),
		buf.x, buf.y, roundi(scale_3d * 100.0), win.x, win.y,
		LightGrid.count(),
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method(),
		_build_line, _bench_line, diag]


func _on_gloom(value: float, max_value: float) -> void:
	_bar.value = value / max_value


func _on_hint(text: String) -> void:
	if _prompt_tw:
		_prompt_tw.kill()
	_prompt_tw = create_tween()
	if text == "":
		_prompt_tw.tween_property(_prompt, "modulate:a", 0.0, 0.25)
	else:
		_prompt.text = text
		_prompt_tw.tween_property(_prompt, "modulate:a", 1.0, 0.25)


## Toasts queue (r29: a second toast in the same moment replaced the first, which was never read).
## A repeat of the one showing is dropped; a long queue shortens each one's hold.
func _on_toast(text: String) -> void:
	if text == "":
		return
	if _toast_busy:
		if text != _toast.text and not _toast_q.has(text) and _toast_q.size() < 4:
			_toast_q.append(text)
		return
	_show_toast(text)


func _show_toast(text: String) -> void:
	_toast_busy = true
	_toast.text = text
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.3 if _toast.modulate.a < 0.5 else 0.15)
	_toast_tw.tween_interval(2.6 if _toast_q.is_empty() else 1.8)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.8 if _toast_q.is_empty() else 0.35)
	_toast_tw.tween_callback(func() -> void:
		_toast_busy = false
		if not _toast_q.is_empty():
			_show_toast(_toast_q.pop_front()))


func _on_hollowed() -> void:
	var n := 1
	var p := get_tree().get_first_node_in_group(Groups.PLAYER)
	if p:
		n = int(p.get("hollow_count"))
	if n <= 1:
		_on_toast("Hollowed.")
	else:
		_on_toast("Hollowed. The dark has taken you %d times." % n)
	create_tween().tween_property(_fade, "color:a", 1.0, 0.6)


func _on_respawned(_at: Vector3) -> void:
	create_tween().tween_property(_fade, "color:a", 0.0, 1.0).set_delay(0.2)


func _on_zone(title: String, subtitle: String) -> void:
	if Travel.returning:
		Travel.returning = false
		return
	# the night's title card waits for the loading screen to lift (it used to play under it)
	var cover := _loading_cover()
	if cover:
		await cover.tree_exited
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.35).timeout
		if not is_inside_tree():
			return
	_title.text = title
	_subtitle.text = subtitle
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	var tt := create_tween()
	tt.tween_interval(0.4)
	tt.tween_property(_title, "modulate:a", 1.0, 0.8)
	tt.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.0)
	tt.tween_interval(3.2)
	tt.tween_property(_title, "modulate:a", 0.0, 1.0)
	tt.parallel().tween_property(_subtitle, "modulate:a", 0.0, 1.0)


# --- the first minutes: controls card and first-time tips (r29) --------------------------------------

func _loading_cover() -> Node:
	var zone := get_parent()
	return zone.get_node_or_null("LoadingScreen") if zone else null


## A menu, the dialogue or the Satchel is open: the card and the tips step aside.
func _menu_open() -> bool:
	return get_tree().paused or (_seen_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)


## The controls card: up once the night shows, gone after CARD_TIME of play (time in menus doesn't
## count), hidden while a menu is open.
func _card_tick(delta: float) -> void:
	if _card_t < 0.0:
		if _life > 0.5 and _loading_cover() == null:
			# r33: a first-minutes hint, once per save (the settings menu can call it back)
			_card_t = CARD_TIME + 1.0 if Hints.seen(&"controls_card") else 0.0
		else:
			return
	if _card_t <= CARD_TIME and _card_t + delta > CARD_TIME:
		_mark_card_seen()
	var menu := _menu_open()
	if not menu:
		_card_t += delta
	var want := 0.0 if menu or _card_t > CARD_TIME else 1.0
	_card_a = move_toward(_card_a, want, delta * (4.0 if want < _card_a else 1.6))
	_hint.modulate.a = _card_a
	_hint.visible = _card_a > 0.001


## r33: bring the controls card back for another CARD_TIME (the settings menu's button).
func show_card() -> void:
	_hint.text = _card_text()
	_card_t = 0.0


func _mark_card_seen() -> void:
	var l: Variant = Travel.story.get("lessons", {})
	var d: Dictionary = l if l is Dictionary else {}
	d["controls_card"] = true
	Travel.story["lessons"] = d


func _card_text() -> String:
	# four short lines (the longest ~75 characters): clear of the objectives at the top right even
	# on the 1600-wide canvas small windows get
	if _pad:
		return "Left stick  move   ·   L3  sprint   ·   A  jump, again in the air\n" \
			+ "B  slide, or roll when slow   ·   R3  lock on   ·   X  use\n" \
			+ "Skills: the triggers, bumpers and Y (the bar below)\n" \
			+ "D-pad  satchel · journal · tasks · kindling   ·   Menu  settings"
	return "WASD  move   ·   %s  sprint   ·   %s  jump, again in the air\n" % [_key("sprint", "Shift"), _key("jump", "Space")] \
		+ "%s  slide   ·   %s  roll   ·   %s  lock on   ·   %s  next target   ·   %s  use\n" % [_key("slide", "Ctrl"), _key("dodge", "V"), _key("lock_on", "MMB"), _key("target_next", "T"), _key("interact", "E")] \
		+ "Skills: the mouse buttons and the keys on the bar below\n" \
		+ "%s  satchel  ·  %s  journal  ·  %s  tasks  ·  %s  kindling  ·  Esc  settings" % [
			_key("inventory", "Tab"), _key("codex", "J"), _key("quest_log", "L"), _key("kindling", "K")]


## The first key or mouse button bound to `action` (rebinding-proof), else `fallback`.
func _key(action: String, fallback: String) -> String:
	if not InputMap.has_action(action):
		return fallback
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
		if ev is InputEventMouseButton:
			return String({MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get((ev as InputEventMouseButton).button_index, fallback))
	return fallback


## First-time tips, one at a time, each once per session, when the moment for it comes up (after the
## card has gone, so they are not a second wall of text).
func _tips_tick(delta: float) -> void:
	_tip_check -= delta
	if _tip_check > 0.0:
		return
	_tip_check = 0.25
	if _card_t < CARD_TIME * 0.6 or _menu_open() or (_tip_tw and _tip_tw.is_running()):
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or not p.is_inside_tree():
		return
	var v: Vector3 = p.get("velocity") if p.get("velocity") != null else Vector3.ZERO
	var flat := Vector2(v.x, v.z).length()
	_sprint_t = _sprint_t + 0.25 if flat > 6.5 and p.call("is_grounded") else 0.0
	if p.has_method("is_hanging") and p.call("is_hanging"):
		_tip_once("hang", "%s  climb up   ·   push away + %s  kick off   ·   %s  let go" % [_pk("jump", "A"), _pk("jump", "A"), _pk("slide", "B")])
	elif _sprint_t > 1.5:
		_tip_once("slide", "%s  while running: slide   ·   %s  in a slide: a long leap" % [_pk("slide", "B"), _pk("jump", "A")])
	elif p.has_method("lock_target") and p.call("lock_target") == null and _foe_near(p, 16.0):
		_tip_once("lock", "%s  lock on to it   ·   %s  roll through a blow" % [_pk("lock_on", "R3"), _pk("dodge", "B")])
	elif float(p.get("gloom")) > 55.0:
		_tip_once("gloom", "The Gloom fills away from light. Stand in firelight to let it drain.")


## A combat lesson (ui/hints.gd): shown in the tip line, after any tip already showing.
func lesson(text: String) -> void:
	if _tip_tw and _tip_tw.is_running():
		if _lessons.size() < 4 and not _lessons.has(text):
			_lessons.append(text)
		return
	_show_tip(text)


func _tip_once(id: String, text: String) -> void:
	if _tips_done.has(id):
		return
	_tips_done[id] = true
	_show_tip(text)


func _show_tip(text: String) -> void:
	_tip.text = text
	if _tip_tw:
		_tip_tw.kill()
	_tip_tw = create_tween()
	_tip_tw.tween_property(_tip, "modulate:a", 1.0, 0.35)
	_tip_tw.tween_interval(5.0)
	_tip_tw.tween_property(_tip, "modulate:a", 0.0, 0.8)
	_tip_tw.tween_callback(func() -> void:
		if not _lessons.is_empty():
			_show_tip.call_deferred(String(_lessons.pop_front())))


## Key or pad name for a tip, by the device in use.
func _pk(action: String, pad_name: String) -> String:
	if _pad:
		return pad_name
	return _key(action, action)


func _foe_near(p: Node3D, r: float) -> bool:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		var n := e as Node3D
		if n and n.global_position.distance_squared_to(p.global_position) < r * r and (not n.has_method("is_alive") or n.call("is_alive")):
			return true
	return false

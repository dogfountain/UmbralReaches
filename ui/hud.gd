extends CanvasLayer
## HUD: Gloom meter, interaction prompt, toasts, zone title card, controls hint, debug stats, Hollowed fade.
## Built in code so layout stays in one file; the base canvas is 1920x1080 and scales with the window.
## r33 (after WoW's interface): the Gloom meter lives in the wanderer's unit frame now (ui/unit_frames.gd,
## with the target and boss frames and the cast bar), floating combat text (ui/combat_text.gd) and
## an XP strip (ui/xp_bar.gd, only once XP exists). The plain bar stays as the fallback when the
## frames are switched off in settings.
## the controls card is gone. A one-line prompt shows the first time each action matters (a ledge,
## a foe in range...), once per save (Hints.once). Every transient line of text goes through the
## TextDirector (ui/text_director.gd): lanes, priorities, one banner at a time.

const Med := preload("res://ui/medieval_style.gd")
const LILAC := Med.GILT
const LANTERN := Color("#FFB347")
const EMBER := Color("#FF5A1F")
const VOID := Color("#05040D")
const QUIET := Color(Med.BONE, 0.9)

const BAKE_INFO := "res://world/zones/ascension/bake_info.gd"
const BOOT_DIAG := preload("res://core/debug/boot_diag.gd")

var _font: Font
var _build_line := ""
var _bench_line := ""
var _bar: GloomBar
var _prompt: Label
var _title: Label
var _subtitle: Label
var _debug: Label
var _fade: ColorRect
var _prompt_tw: Tween
var _debug_t := 0.0
var _measure_rid: RID
# r29 (critique B): the first minutes. The title card and the controls used to play out under the
# loading screen (title gone, hint half faded by the time the night shows); the hint was one 200-
# character keyboard-only line that ran under the objectives and stayed up over every menu.
var _pad := false                 ## the last input came from a gamepad: the card and tips use pad names
var _seen_capture := false        ## the mouse has been captured once (menus free it: a "menu open" cue)
var _life := 0.0
var _ui: Control                  ## everything but the fade
var _compass: Control
var _minimap: Control
var _td: Node                     ## the text arbiter (ui/text_director.gd)
var _tip_check := 0.0
var _sprint_t := 0.0
var _aim: Control
var _gloom_label: Label
var _card_req := 0
var _air_t := 0.0
const HudPrefs := preload("res://ui/hud_prefs.gd")
const Hints := preload("res://ui/hints.gd")
const TextDirector := preload("res://ui/text_director.gd")


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
		draw_rect(r, Color(0.03, 0.02, 0.012, 0.85))
		var t := value
		var fill := Color("#A98BFF").lerp(Color("#FF5A1F"), smoothstep(0.5, 1.0, t))
		if t > 0.75:
			fill = fill.lightened(0.25 * (0.5 + 0.5 * sin(pulse * 9.0)))
		draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4.0) * t, size.y - 4.0)), fill)
		for i in range(1, 4):   # quarter ticks
			var x := size.x * i / 4.0
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0, 0, 0, 0.6), 2.0)
		draw_rect(r, Color(0.05, 0.03, 0.015), false, 3.0)               # forged rim: dark outline, bronze edge, rivets at the ends
		draw_rect(r.grow(-1.0), Color(Med.BRONZE, 0.95), false, 1.5)
		for rx in [2.0, size.x - 2.0]:
			draw_circle(Vector2(rx, size.y * 0.5), 2.2, Med.BRONZE.lightened(0.3))


func _ready() -> void:
	layer = 10
	add_to_group(&"hud")                         # ui/hints.gd finds the tip line here
	process_mode = Node.PROCESS_MODE_ALWAYS     # the card and the crosshair step aside while the tree is paused
	_font = load("res://ui/fonts/Cinzel.ttf")
	var outer := Control.new()                  # the fade sits here, over the whole HUD (root) so an opening can hide the HUD alone
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(root)
	_ui = root

	_td = TextDirector.new()
	_td.name = "TextDirector"
	add_child(_td)
	_td.build(outer, _font)
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

	_title = _label(root, "", 64, Med.GILT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 250
	_title.offset_bottom = 340
	_title.offset_left = -900
	_title.offset_right = 900
	_subtitle = _label(root, "", 26, Med.BONE, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_subtitle.offset_top = 340
	_subtitle.offset_bottom = 380
	_subtitle.offset_left = -900
	_subtitle.offset_right = 900
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	Events.zone_entered.connect(_on_zone)

	if "using_pad" in Settings:
		_pad = bool(Settings.get("using_pad"))
	if Settings.has_signal("input_device_changed"):
		Settings.connect("input_device_changed", _on_device)

	var bar := Hotbar.new()
	bar.name = "Hotbar"
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_top = -136
	bar.offset_bottom = -30
	root.add_child(bar)
	root.add_child(load("res://core/story/objective_line.gd").new())   # objective lines (core/story, story agent)
	_compass = load("res://ui/compass.gd").new()
	root.add_child(_compass)                                           # heading strip + beacon/brazier markers (ENS art pass)
	_minimap = load("res://ui/minimap.gd").new()
	root.add_child(_minimap)                                           # round minimap, bottom right; N: near / wide / off (r32)
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
	outer.add_child(_fade)

	# a new game opens on black with no HUD: the story (core/story/story.gd _opening) lifts it in beats
	HudPrefs.reset_stage()
	if HudPrefs.new_game_open_cached():
		hold_opening(true)
	Events.gloom_changed.connect(_on_gloom)
	Events.interact_hint.connect(_on_hint)
	Settings.changed.connect(func() -> void: TextDirector.rescale(self))
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
	TextDirector.scaled(l, size)
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


func _process(delta: float) -> void:
	var legacy := not HudPrefs.unit_frames     # r33: the frames carry the Gloom; the old bar is the fallback
	HudPrefs.note_gloom(_bar.value)
	_bar.visible = legacy and HudPrefs.gloom_known()
	_gloom_label.visible = legacy and HudPrefs.gloom_known()
	_stage_tick(delta)
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
	_tips_tick(delta)
	if _aim:
		_aim.visible = not _menu_open() and not _td.is_up(&"lesson")          # no crosshair over a menu, a conversation or a lesson
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


## Toasts go through the text director: it queues them (two at most on screen, bottom left corner),
## holds them while narration, a dialogue box or a lock-on fight has the screen, and writes them in
## sentence case.
func _on_toast(text: String) -> void:
	if text != "":
		_td.post_toast(text)


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
	if _opening_hold:
		_card_after = [title, subtitle]          # the card waits for the opening: it plays when the HUD arrives
		return
	# the night's title card waits for the loading screen to lift, and for the text director's banner lane
	# (narration, a dialogue box or a fight hold it)
	_title_pending += 1
	var cover := _loading_cover()
	if cover:
		await cover.tree_exited
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.35).timeout
	var tries := 0
	while is_inside_tree() and not _td.can_begin(&"title") and tries < 60:
		tries += 1
		await get_tree().create_timer(0.25).timeout
	_title_pending -= 1
	if not is_inside_tree():
		return
	_td.begin(&"title", 6.8, Rect2(_td.lane_rect(&"banner").position, Vector2(1100.0, 280.0)), true)
	_title.text = title
	_subtitle.text = subtitle
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	var tt := create_tween()
	_title_tw = tt
	tt.tween_interval(0.4)
	tt.tween_property(_title, "modulate:a", 1.0, 0.8)
	tt.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.0)
	tt.tween_interval(3.2)
	tt.tween_property(_title, "modulate:a", 0.0, 1.0)
	tt.parallel().tween_property(_subtitle, "modulate:a", 0.0, 1.0)


var _title_pending := 0            ## title cards waiting for the loading screen to lift
var _title_tw: Tween


## r35: a zone title card is waiting for the loading screen or still on screen (its whole tween, fade
## out included). The place banners (discovery_banner.gd, codex.gd) hold while this is true. They are
## built after the arrival card is called, so they never heard it, and "HEARTHWARD" was carved over
## "THE UMBRAL REACHES" the moment the loading screen lifted.
func title_busy() -> bool:
	return _title_pending > 0 or (_title_tw != null and _title_tw.is_valid() and _title_tw.is_running())


# --- the first minutes: controls card and first-time tips (r29) --------------------------------------

func _loading_cover() -> Node:
	var zone := get_parent()
	return zone.get_node_or_null("LoadingScreen") if zone else null


## A menu, the dialogue or the Satchel is open: the card and the tips step aside.
func _menu_open() -> bool:
	return get_tree().paused or (_seen_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)


## The old controls card is retired. This replays the one-line prompts (settings menu: "Show Again"):
## each is forgotten, so it shows the next time its moment comes.
func show_card() -> void:
	var l: Variant = Travel.story.get("lessons", {})
	if l is Dictionary:
		for id: String in PROMPTS:
			(l as Dictionary).erase("tip_" + id)
	_air_t = 0.0


## The ids of the just-in-time prompts (each is a Hints lesson "tip_<id>", once per save).
const PROMPTS := ["move", "jump2", "hang", "slide", "lock", "gloom", "roll", "ride"]


## The first key or mouse button bound to `action` (rebinding-proof), else `fallback`.
func _key(action: String, fallback: String) -> String:
	return InputSetup.live_label(action, false, fallback)


## Just-in-time prompts: one line, the first time an action matters, once per save. They go to the
## text director's lesson lane (queued behind narration, shown during a fight).
func _tips_tick(delta: float) -> void:
	_tip_check -= delta
	if _tip_check > 0.0:
		return
	_tip_check = 0.25
	if _menu_open() or (not staged_in() and not _lifting):
		return
	var zn := get_tree().current_scene
	if zn != null and zn.get_node_or_null("LoadingScreen") != null:
		return                         # the cover is still up: no lesson over a tour
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or not p.is_inside_tree():
		return
	var v: Vector3 = p.get("velocity") if p.get("velocity") != null else Vector3.ZERO
	var flat := Vector2(v.x, v.z).length()
	var grounded: bool = bool(p.call("is_grounded")) if p.has_method("is_grounded") else true
	_sprint_t = _sprint_t + 0.25 if flat > 6.5 and grounded else 0.0
	_air_t = 0.0 if grounded else _air_t + 0.25
	if p.has_method("is_hanging") and p.call("is_hanging"):
		_jit("hang", "%s  climb up   ·   push away + %s  kick off   ·   %s  let go" % [_pk("jump", "A"), _pk("jump", "A"), _pk("slide", "B")])
	elif p.get("riding") != null:
		_jit("ride", "%s  leap   ·   %s  get down" % [_pk("jump", "A"), _pk("interact", "X")])
	elif not staged_in():
		_jit("move", "%s  move   ·   mouse  look   ·   %s  sprint   ·   %s  jump" % [_pk_move(), _pk("sprint", "L3"), _pk("jump", "A")])
	elif not Hints.seen(&"tip_move"):
		_jit("move", "%s  move   ·   mouse  look   ·   %s  sprint   ·   %s  jump" % [_pk_move(), _pk("sprint", "L3"), _pk("jump", "A")])
	elif _air_t > 0.4:
		_jit("jump2", "%s again in the air: a second jump" % _pk("jump", "A"))   # the first ledge or leap
	elif _sprint_t > 1.5:
		_jit("slide", "%s  while running: slide   ·   %s  in a slide: a long leap" % [_pk("slide", "B"), _pk("jump", "A")])
	elif p.has_method("lock_target") and p.call("lock_target") == null and _foe_near(p, 16.0):
		_jit("lock", "%s  lock on to it   ·   %s  roll through a blow" % [_pk("lock_on", "R3"), _pk("dodge", "B")])
	elif p.get("gloom") != null and float(p.get("gloom")) > 55.0:
		_jit("gloom", "The Gloom fills away from light. Full, it takes shape and hunts you. Firelight drains it.")


## A just-in-time prompt, once per save.
func _jit(id: String, text: String) -> void:
	Hints.once(StringName("tip_" + id), text)


func _pk_move() -> String:
	if _pad:
		return "Left stick"
	var keys: Array = ["move_forward", "move_left", "move_back", "move_right"].map(func(a: String) -> String: return InputSetup.live_label(a, false, "?"))
	return "WASD" if "".join(keys) == "WASD" else " ".join(keys)


## A combat lesson (ui/hints.gd), or a prompt: the text director's lesson lane.
func lesson(text: String) -> void:
	_td.post_lesson(text)


## The HUD is on screen (the opening is staged: see core/story/story.gd). True outside a new game's first beats.
func staged_in() -> bool:
	return not _opening_hold


var _opening_hold := false
var _card_after: Array = []
var _lifting := false                  ## the black has lifted but the HUD has not arrived: only the move prompt shows
var _stage_t := 0.0


## the staged opening of a new game (core/story/story.gd calls these three in order):
##   hold_opening(true)   black, no HUD (the HUD does this itself at boot when the game is new)
##   fade_in_opening()    the black lifts over the world; the HUD stays away
##   hold_opening(false)  the HUD arrives (what has not been earned yet stays hidden: see _stage_tick)
func hold_opening(on: bool) -> void:
	_opening_hold = on
	_ui.visible = not on
	if on:
		_fade.color.a = 1.0
	elif not _card_after.is_empty():
		var c := _card_after
		_card_after = []
		_on_zone(String(c[0]), String(c[1]))


func fade_in_opening(seconds := 3.0) -> void:
	_lifting = true
	create_tween().tween_property(_fade, "color:a", 0.0, seconds)


## The pieces of the HUD that come later: the compass and the minimap with the Keep (met_keep).
func _stage_tick(delta: float) -> void:
	_stage_t -= delta
	if _stage_t > 0.0:
		return
	_stage_t = 0.3
	var flags: Variant = Travel.story.get("flags", {})
	var met: bool = flags is Dictionary and bool((flags as Dictionary).get("met_keep", false))
	met = met or not HudPrefs.new_game_open_cached()      # only a new game keeps them back
	if _compass:
		_compass.visible = met
	if _minimap:
		_minimap.visible = met


## Key or pad name for a tip, by the device in use.
func _pk(action: String, pad_name: String) -> String:
	return InputSetup.live_label(action, _pad, pad_name if _pad else action)


func _foe_near(p: Node3D, r: float) -> bool:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		var n := e as Node3D
		if n and n.global_position.distance_squared_to(p.global_position) < r * r and (not n.has_method("is_alive") or n.call("is_alive")):
			return true
	return false

extends CanvasLayer
## HUD: Gloom meter, interaction prompt, toasts, zone title card, controls hint, debug stats, Hollowed fade.
## Built in code so layout stays in one file; the base canvas is 1920x1080 and scales with the window.

const LILAC := Color("#A98BFF")
const LANTERN := Color("#FFB347")
const EMBER := Color("#FF5A1F")
const VOID := Color("#05040D")
const QUIET := Color(0.72, 0.74, 0.86, 0.85)

const BAKE_INFO := "res://world/zones/ascension/bake_info.gd"

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
	_font = load("res://ui/fonts/Cinzel.ttf")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var gl := _label(root, "GLOOM", 22, QUIET)
	gl.position = Vector2(48, 36)
	_bar = GloomBar.new()
	_bar.position = Vector2(48, 72)
	_bar.size = Vector2(380, 16)
	root.add_child(_bar)

	_prompt = _label(root, "", 30, LANTERN, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -200
	_prompt.offset_bottom = -160
	_prompt.offset_left = -500
	_prompt.offset_right = 500
	_prompt.modulate.a = 0.0

	_toast = _label(root, "", 26, Color(0.85, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 150
	_toast.offset_bottom = 190
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

	_hint = _label(root, "WASD move  ·  Mouse look  ·  Shift sprint  ·  Space jump  ·  LMB / Q bolt  ·  RMB / R heavy  ·  E kindle  ·  F1 grade on/off  ·  Esc / F2 settings  ·  F3 stats  ·  F4 render scale  ·  F8 benchmark  ·  F9 demo walk  ·  F11 fullscreen", 18, QUIET)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 48
	_hint.offset_top = -64
	_hint.offset_bottom = -36
	_hint.offset_right = 1800
	var ht := create_tween()
	ht.tween_interval(16.0)
	ht.tween_property(_hint, "modulate:a", 0.0, 2.0)

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


func _process(delta: float) -> void:
	_bar.pulse += delta
	_bar.queue_redraw()
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
	var buf := Vector2i(roundi(float(win.x) * scale_3d), roundi(float(win.y) * scale_3d))
	var fps := maxi(Engine.get_frames_per_second(), 1)
	var diag_script := load("res://core/debug/boot_diag.gd")
	var diag: String = diag_script.summary if diag_script != null else "diag script missing"
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


func _on_toast(text: String) -> void:
	_toast.text = text
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.4)
	_toast_tw.tween_interval(2.6)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.8)


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

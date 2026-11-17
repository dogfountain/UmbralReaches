extends CanvasLayer
## The title screen: shown on a real launch, before the world is built. Built in code (no scene).
##   Continue    (if a save exists)  -> the save slots that hold one; one tap if only one does
##   New Game                         -> a slot; an occupied slot asks twice before it is wiped
##   Settings                         -> the settings menu (its own instance)
##   Quit
## Emits chosen(slot, fresh); ui/title_boot.gd starts the night from it. Skipped by tests, harness flags,
## headless runs and --fresh: see wanted().
## Load by path (no class_name): const TitleScreen := preload("res://ui/title_screen.gd")

signal chosen(slot: int, fresh: bool)

const UIType := preload("res://ui/type.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const SettingsMenu := preload("res://ui/settings_menu.gd")
const Med := preload("res://ui/medieval_style.gd")
const LILAC := Med.BONE_DIM
const INK := Med.BONE
const DIM := Color(Med.BONE_DIM, 0.9)
## Launch flags that mean "a harness is running this": the title would only stand in its way.
const SKIP_FLAGS := ["--bench", "--perf-baseline", "--test-shade", "--walk-rec",
	"--save-dir", "--fresh", "--no-title", "--loading", "--dev-start"]

var _menu: VBoxContainer
var _slots: VBoxContainer
var _title_col: VBoxContainer
var _note: Label
var _settings: CanvasLayer
var _mode := ""                   ## "continue" or "new" while the slot list is up
var _armed := -1                  ## the occupied slot a New Game is waiting to wipe
var _buttons: Array[Button] = []
var _done := false


## Should this launch open on the title screen?
static func wanted() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for a in OS.get_cmdline_user_args():
		for f: String in SKIP_FLAGS:
			if a == f or a.begins_with(f + "="):
				return false
	return true


var _keys_hint: Label


## The title's foot: the keyboard's keys, or the pad's buttons while the last input was a pad.
func _refresh_keys() -> void:
	if _keys_hint != null:
		_keys_hint.text = "[D-pad] choose      [A] select      [B] back" if Settings.using_pad else "[W / S] choose      [Enter] select      [Esc] back"


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = bg_colour()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var backdrop := _Backdrop.new()                   # the night the game is about: the sky turning inward over the Crowns, a fire at the foot
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var glow := TextureRect.new()                     # a warm pool of firelight behind the emblem and the title
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.texture = _glow_texture()
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.modulate.a = 0.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 1.0, 4.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "modulate:a", 0.7, 4.0).set_trans(Tween.TRANS_SINE)
	var shade := TextureRect.new()                    # a dark pool behind the column: the title and the plates read against it, not the sky
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.texture = _shade_texture()
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var vig := _Border.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = Med.theme()
	add_child(center)
	_title_col = VBoxContainer.new()
	_title_col.add_theme_constant_override("separation", 10)
	center.add_child(_title_col)
	var crest := _Crest.new()
	crest.custom_minimum_size = Vector2(120, 140)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_col.add_child(crest)
	var crown := Med.rule(Med.GILT_DEEP)
	crown.custom_minimum_size = Vector2(520, 18)
	crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_col.add_child(crown)
	var ttl := _label("THE UMBRAL REACHES", 76, Med.GILT, UIType.title(), true)
	Med.gilt(ttl, 76, Color(1.0, 0.84, 0.46))
	ttl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	ttl.add_theme_constant_override("shadow_offset_y", 3)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_col.add_child(ttl)
	var tail := Med.rule(Med.GILT_DEEP)
	tail.custom_minimum_size = Vector2(520, 18)
	tail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_col.add_child(tail)
	_title_col.add_child(_label("where the sky turns inward", 26, Med.BONE, UIType.body(), true))
	_title_col.add_child(_gap(40))
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.custom_minimum_size = Vector2(440, 0)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_col.add_child(_menu)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	_slots.custom_minimum_size = Vector2(640, 0)
	_slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_col.add_child(_slots)
	_note = _label("", 20, Med.BONE_DIM, UIType.body(), true)
	_title_col.add_child(_gap(10))
	_title_col.add_child(_note)
	var keys := _label("", 16, Med.BONE_DIM, UIType.body(), true)
	_keys_hint = keys
	_refresh_keys()
	Settings.input_device_changed.connect(func(_pad: bool) -> void: _refresh_keys())
	keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	keys.offset_top = -86
	keys.offset_bottom = -56
	keys.offset_left = -400
	keys.offset_right = 400
	add_child(keys)
	_show_main()
	_veil()


## Everything is drawn once under an opaque veil (glyph atlases, the gilt outline, the theme's styleboxes),
## then the veil lifts: the first visible frames are smooth instead of paying those one-time costs on screen.
func _veil() -> void:
	var veil := ColorRect.new()
	veil.color = bg_colour()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	for i in 3:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(veil, "color:a", 0.0, 0.4)
	tw.tween_callback(veil.queue_free)


static func bg_colour() -> Color:
	return Color(0.03, 0.02, 0.012, 1.0)


func _label(text: String, size: int, col: Color, font: Font, centred := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _button(parent: Control, text: String, on_press: Callable, size := 26) -> Button:
	var b := _MenuButton.new()
	b.text = text
	b.add_theme_font_override("font", UIType.title())
	b.add_theme_font_size_override("font_size", size)
	Med.style_button(b, size, 28, 8)
	var lit := Color(1.0, 0.9, 0.62)
	b.add_theme_color_override("font_color", Color(0.96, 0.9, 0.76))
	b.add_theme_color_override("font_hover_color", lit)
	b.add_theme_color_override("font_focus_color", lit)
	b.add_theme_color_override("font_pressed_color", Med.GILT)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.44, 0.35))
	b.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01))
	b.add_theme_constant_override("outline_size", 3)
	var norm := Med.plaque("normal", 28, 8)
	norm.modulate_color = Color(1.35, 1.25, 1.1)           # the resting plate is lifted out of the dark
	b.add_theme_stylebox_override("normal", norm)
	var hov := Med.plaque("hover", 28, 8)
	hov.modulate_color = Color(1.2, 1.12, 1.0)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("focus", hov)
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(func() -> void:
		UiSound.play(self, "confirm")
		on_press.call())
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	parent.add_child(b)
	_buttons.append(b)
	return b


func _clear(box: Container) -> void:
	for c in box.get_children():
		if c is Button:
			_buttons.erase(c)
		box.remove_child(c)
		c.queue_free()


## A menu plate: the lit one carries a gilt lozenge at each end.
class _MenuButton extends Button:
	func _draw() -> void:
		if disabled or not (has_focus() or is_hovered()):
			return
		for side: float in [0.0, 1.0]:
			var c := Vector2(18.0 if side == 0.0 else size.x - 18.0, size.y * 0.5)
			var d := 7.0
			var pts := PackedVector2Array([c + Vector2(-d, 0), c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d)])
			draw_colored_polygon(pts, Color(0.95, 0.78, 0.4))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.15, 0.07, 0.02), 1.5)


## A soft dark ellipse, centred on the column of title and menu.
static func _shade_texture() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.012, 0.01, 0.78), Color(0.02, 0.012, 0.01, 0.55), Color(0.02, 0.012, 0.01, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.95, 0.5)
	t.width = 256
	t.height = 144
	return t


## The backdrop, drawn in code: a night sky that grades from indigo to the ember of a far fire, stars, faint rings
## turning inward (the sky of the story), three ridges of the Crowns and the small fire at their foot.
class _Backdrop extends Control:
	var _stars: Array[Vector3] = []              ## x, y (0..1), size/phase
	var _t := 0.0
	var _acc := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 38
		for i in 170:
			_stars.append(Vector3(rng.randf(), pow(rng.randf(), 1.4) * 0.74, rng.randf()))

	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		if _acc > 0.05:
			_acc = 0.0
			queue_redraw()

	func _ridge(y0: float, amp: float, seed_: float, col: Color) -> void:
		var pts := PackedVector2Array()
		var n := 48
		for i in n + 1:
			var u := float(i) / float(n)
			# peaks: the ridge is a sum of |sin| (sharp crests, soft saddles), not rolling hills
			var h := pow(absf(sin(u * 5.0 + seed_)), 0.8) * 0.55 + pow(absf(sin(u * 13.0 + seed_ * 2.3)), 1.2) * 0.3 + sin(u * 2.3 + seed_ * 0.7) * 0.25
			pts.append(Vector2(u * size.x, y0 - (h * 0.7 + 0.2) * amp))
		pts.append(Vector2(size.x, size.y))
		pts.append(Vector2(0, size.y))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var hz := h * 0.80
		# the sky: four bands, the colour carried between them by vertex colour
		var rows := [[0.0, Color(0.015, 0.015, 0.06)], [0.38, Color(0.05, 0.04, 0.13)], [0.64, Color(0.17, 0.08, 0.17)], [0.8, Color(0.42, 0.2, 0.1)]]
		for i in rows.size() - 1:
			var y0: float = float(rows[i][0]) * h
			var y1: float = float(rows[i + 1][0]) * h
			var c0: Color = rows[i][1]
			var c1: Color = rows[i + 1][1]
			draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]), PackedColorArray([c0, c0, c1, c1]))
		draw_rect(Rect2(0, hz, w, h - hz), Color(0.03, 0.02, 0.02))
		# the rings turning inward over the middle of the sky
		var ctr := Vector2(w * 0.5, h * 0.3)
		for k in 14:
			var r := 90.0 + float(k) * 62.0
			var a0 := _t * 0.03 * (1.0 + float(k % 3) * 0.4) + float(k) * 0.9
			draw_arc(ctr, r, a0, a0 + 2.6 + float(k % 4) * 0.5, 64, Color(0.62, 0.5, 0.95, 0.07 + 0.012 * float(k % 3)), 2.0 + float(k % 2) * 2.0, true)
		# stars, twinkling a little
		for st in _stars:
			var tw := 0.55 + 0.45 * sin(_t * (0.8 + st.z * 1.6) + st.z * 40.0)
			var a := (0.35 + 0.55 * st.z) * tw
			var sz := 1.0 + st.z * 1.4
			draw_rect(Rect2(st.x * w, st.y * h, sz, sz), Color(0.85, 0.88, 1.0, a))
		# the Crowns: three ridges, the far one lit by the horizon
		_ridge(hz - 6.0, h * 0.26, 0.4, Color(0.15, 0.08, 0.14))
		_ridge(hz + 12.0, h * 0.18, 2.1, Color(0.085, 0.05, 0.09))
		_ridge(hz + 38.0, h * 0.12, 4.6, Color(0.04, 0.025, 0.045))
		# the fire at their foot: a pool of light and a small flame, flickering
		var fc := Vector2(w * 0.5, hz + 70.0)
		var fl := 0.8 + 0.2 * sin(_t * 7.3) * sin(_t * 3.1)
		for k in 6:
			draw_circle(fc + Vector2(0, -6), 230.0 - 34.0 * float(k), Color(1.0, 0.5, 0.18, 0.03 * fl))
		draw_colored_polygon(PackedVector2Array([fc + Vector2(-9, 0), fc + Vector2(-4, -14 * fl), fc + Vector2(0, -30 * fl), fc + Vector2(5, -15 * fl), fc + Vector2(9, 0)]), Color(1.0, 0.62, 0.22, 0.95))
		draw_colored_polygon(PackedVector2Array([fc + Vector2(-4.5, 0), fc + Vector2(0, -16 * fl), fc + Vector2(4.5, 0)]), Color(1.0, 0.92, 0.7))
		draw_rect(Rect2(fc + Vector2(-14, 0), Vector2(28, 4)), Color(0.12, 0.07, 0.05))


## A radial pool of warm light, centred a little above the middle of the screen.
static func _glow_texture() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.62, 0.34, 0.12, 0.3), Color(0.34, 0.17, 0.06, 0.12), Color(0.1, 0.05, 0.02, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.42)
	t.fill_to = Vector2(0.5, 1.02)
	t.width = 256
	t.height = 144
	return t


## A thin double rule inset from the screen edge with a bronze square at each corner, like an illuminated page.
class _Border extends Control:
	func _draw() -> void:
		var m := 28.0
		var r := Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0)
		draw_rect(r, Color(0.62, 0.45, 0.2, 0.55), false, 2.0)
		draw_rect(r.grow(-7), Color(0.62, 0.45, 0.2, 0.3), false, 1.0)
		for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), Color(0.78, 0.58, 0.24, 0.9))
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), Color(0.05, 0.03, 0.015), false, 2.0)
			draw_circle(c, 2.5, Color(0.1, 0.05, 0.02))


## A heater shield in oxblood and bronze, bearing a gilt crescent over a small flame.
class _Crest extends Control:
	func _draw() -> void:
		var k := size.y / 112.0
		var c := Vector2(size.x * 0.5, 0.0)
		var pts := PackedVector2Array()
		for p: Vector2 in [Vector2(-40, 6), Vector2(40, 6), Vector2(40, 52), Vector2(26, 82), Vector2(0, 106), Vector2(-26, 82), Vector2(-40, 52)]:
			pts.append(c + p * k)
		draw_colored_polygon(pts, Color(0.5, 0.1, 0.08))
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c + Vector2(40, 30) * k, c + Vector2(-40, 30) * k]), Color(0.58, 0.13, 0.1))
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, Color(0.62, 0.45, 0.2), 5.0, true)
		draw_polyline(ring, Color(0.98, 0.82, 0.46), 2.0, true)
		draw_circle(c + Vector2(0, 42) * k, 20.0 * k, Color(1.0, 0.84, 0.46))
		draw_circle(c + Vector2(8, 38) * k, 18.0 * k, Color(0.46, 0.09, 0.07))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 76) * k, c + Vector2(0, 58) * k, c + Vector2(6, 76) * k]), Color(1.0, 0.84, 0.46))


# --- pages ---------------------------------------------------------------------------------------------

## Focus a button next frame, unless a press has since taken it (and its page) out of the tree.
func _focus_later(c: Control) -> void:
	(func() -> void:
		if is_instance_valid(c) and c.is_inside_tree():
			c.grab_focus()).call_deferred()


func _show_main() -> void:
	_mode = ""
	_armed = -1
	_slots.visible = false
	_menu.visible = true
	_clear(_menu)
	var any := false
	for n in range(1, Travel.SLOTS + 1):
		if bool(Travel.slot_summary(n).exists):
			any = true
	var cont := _button(_menu, "Continue", func() -> void: _open_slots("continue"))
	cont.disabled = not any
	_button(_menu, "New Game", func() -> void: _open_slots("new"))
	_button(_menu, "Settings", _open_settings)
	_button(_menu, "Quit", func() -> void: get_tree().quit())
	_note.text = ""
	_focus_later(cont if any else _buttons[1])


func _open_slots(mode: String) -> void:
	_mode = mode
	_armed = -1
	if mode == "continue":
		var occupied: Array[int] = []
		for n in range(1, Travel.SLOTS + 1):
			if bool(Travel.slot_summary(n).exists):
				occupied.append(n)
		if occupied.size() == 1:                           # one save: no list to choose from
			_choose(occupied[0], false)
			return
	_menu.visible = false
	_slots.visible = true
	_rebuild_slots()


func _rebuild_slots() -> void:
	_clear(_slots)
	_note.text = "Choose a slot to continue." if _mode == "continue" else "Choose a slot for a new game."
	var first: Button = null
	for n in range(1, Travel.SLOTS + 1):
		var info: Dictionary = Travel.slot_summary(n)
		var occupied := bool(info.exists)
		var slot := n
		var text := "Slot %d   ·   %s" % [n, String(info.text) if occupied else "empty"]
		if _mode == "new" and occupied and _armed == n:
			text = "Slot %d   ·   erase it and begin anew?" % n
		var b := _button(_slots, text, func() -> void: _slot_pressed(slot), 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = _mode == "continue" and not occupied
		if first == null and not b.disabled:
			first = b
	_button(_slots, "Back", _show_main, 22)
	if first:
		_focus_later(first)


func _slot_pressed(n: int) -> void:
	var occupied := bool(Travel.slot_summary(n).exists)
	if _mode == "continue":
		_choose(n, false)
	elif not occupied:
		_choose(n, true)
	elif _armed == n:
		_choose(n, true)                                     # the second press: wipe it
	else:
		_armed = n
		_rebuild_slots()
		get_tree().create_timer(4.0, true).timeout.connect(func() -> void:
			if _armed == n and is_inside_tree() and not _done:
				_armed = -1
				_rebuild_slots())


func _choose(n: int, fresh: bool) -> void:
	if _done:
		return
	_done = true
	for b in _buttons:
		if is_instance_valid(b):
			b.disabled = true
	_note.text = "The night is gathering..."
	chosen.emit(n, fresh)


func _open_settings() -> void:
	if _settings == null:
		_settings = SettingsMenu.new()
		_settings.set("on_title", true)
		add_child(_settings)
		_settings.layer = layer + 5          # its _ready sets 70 (the in-game pause layer); here it must sit above the title (125)
	_settings.call("open")


func _input(event: InputEvent) -> void:
	if _done or (_settings != null and bool(_settings.get("_root").visible)):
		return
	if event.is_action_pressed("ui_cancel") and _slots.visible:
		_show_main()
		get_viewport().set_input_as_handled()

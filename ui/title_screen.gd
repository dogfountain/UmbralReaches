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
const LILAC := Color("#A98BFF")
const INK := Color(0.92, 0.9, 1.0)
const DIM := Color(0.62, 0.64, 0.78, 0.9)
## Launch flags that mean "a harness is running this": the title would only stand in its way.
const SKIP_FLAGS := ["--demo", "--bench", "--perf-baseline", "--test-shade", "--walk-rec", "--deepdive", "--shots-dir",
	"--save-dir", "--fresh", "--no-title", "--quit-after-demo", "--loading", "--dev-start"]

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


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.01, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var glow := ColorRect.new()                       # a faint violet low light, nothing more
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(0.1, 0.06, 0.2, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "color:a", 0.22, 4.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "color:a", 0.06, 4.0).set_trans(Tween.TRANS_SINE)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_title_col = VBoxContainer.new()
	_title_col.add_theme_constant_override("separation", 10)
	center.add_child(_title_col)
	_title_col.add_child(_label("THE UMBRAL REACHES", 72, INK, UIType.title(), true))
	_title_col.add_child(_label("where the sky turns inward", 24, LILAC, UIType.body(), true))
	_title_col.add_child(_gap(46))
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.custom_minimum_size = Vector2(360, 0)
	_title_col.add_child(_menu)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	_slots.custom_minimum_size = Vector2(560, 0)
	_title_col.add_child(_slots)
	_note = _label("", 18, DIM, UIType.body(), true)
	_title_col.add_child(_gap(10))
	_title_col.add_child(_note)
	_show_main()


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


func _button(parent: Control, text: String, on_press: Callable, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", UIType.title())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.custom_minimum_size = Vector2(0, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.045, 0.12, 0.85)
	sb.border_color = Color(0.5, 0.4, 0.8, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.16, 0.1, 0.3, 0.95)
	hov.border_color = LILAC
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("disabled", sb)
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


# --- pages ---------------------------------------------------------------------------------------------

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
	(cont if any else _buttons[1]).grab_focus.call_deferred()


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
		var b := _button(_slots, text, func() -> void: _slot_pressed(slot), 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = _mode == "continue" and not occupied
		if first == null and not b.disabled:
			first = b
	_button(_slots, "Back", _show_main, 20)
	if first:
		first.grab_focus.call_deferred()


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
	_settings.call("open")


func _input(event: InputEvent) -> void:
	if _done or (_settings != null and bool(_settings.get("_root").visible)):
		return
	if event.is_action_pressed("ui_cancel") and _slots.visible:
		_show_main()
		get_viewport().set_input_as_handled()

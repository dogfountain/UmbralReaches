class_name VowPanel
extends CanvasLayer
## The vow panel (core/life/progression/vows.gd): three vows for the tier just reached, each a button with its name, its Path and
## what it does to how the night is played. Pick one (it is described and a "Swear it" button appears: a vow is for good), or
## leave with Esc / B and be offered again in two minutes. Keyboard, mouse and pad (the buttons take focus: d-pad / stick and A).
## Pauses the night; built hidden at the start. Class VowPanel.

const Med := preload("res://ui/medieval_style.gd")
const MenuGate := preload("res://ui/menu_gate.gd")
const UiSound := preload("res://ui/ui_sound.gd")

const INK := Color(0.93, 0.87, 0.74)
const DIM := Color(0.74, 0.66, 0.52)
const GILT := Color(1.0, 0.78, 0.4)

var _open := false
var _was_captured := false
var _tier := -1
var _sel := ""
var _root: Control
var _title: Label
var _sub: Label
var _list: VBoxContainer
var _opened_ms := 0


func _ready() -> void:
	name = "VowPanel"
	layer = 52
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"vow_panel")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.012, 0.01, 0.84)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Med.panel("leather", 36))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -430.0
	panel.offset_right = 430.0
	panel.offset_top = -270.0
	panel.offset_bottom = 270.0
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Med.gilt(_title, 32)
	col.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_override("font", load("res://ui/fonts/body_serif.ttf") as Font)
	_sub.add_theme_font_size_override("font_size", 17)
	_sub.add_theme_color_override("font_color", DIM)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub)
	col.add_child(Med.rule())
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_list)
	_root.visible = false


func open_for(tier: int) -> void:
	if _open or tier < 0 or get_tree().paused or MenuGate.blocked(self):
		return
	_tier = tier
	_sel = ""
	_open = true
	_opened_ms = Time.get_ticks_msec()
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_fill()
	_root.visible = true
	UiSound.play(self, "tab")


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UiSound.play(self, "back")


func _fill() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_title.text = "A VOW"
	_sub.text = "Level %d. Three vows are offered. One is sworn, and it is yours for the rest of the night." % int(Vows.TIERS[_tier])
	var first: Button = null
	for id in Vows.options(_tier):
		var d: Array = Vows.DEFS[id]
		var vid: String = id
		var b := Button.new()
		b.text = "%s   ·   the %s\n%s" % [String(d[2]), String(d[1]), String(d[3])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(780, 84)
		Med.style_button(b, 18, 16, 8)
		b.toggle_mode = false
		b.pressed.connect(func() -> void:
			_sel = vid
			UiSound.play(self, "tab")
			_fill())
		if _sel == vid:
			b.text = "> " + b.text
		_list.add_child(b)
		if first == null or _sel == vid:
			first = b
	var swear := Button.new()
	swear.text = "Swear it" if _sel != "" else "Choose a vow"
	swear.disabled = _sel == ""
	swear.focus_mode = Control.FOCUS_ALL if _sel != "" else Control.FOCUS_NONE
	Med.style_button(swear, 20, 20, 8)
	swear.pressed.connect(func() -> void:
		Vows.choose(_tier, _sel)
		UiSound.play(self, "confirm")
		close())
	_list.add_child(swear)
	var later := Label.new()
	later.text = "[Esc] or B: not yet. You will be asked again."
	later.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	later.add_theme_font_override("font", load("res://ui/fonts/body_serif.ttf") as Font)
	later.add_theme_font_size_override("font_size", 15)
	later.add_theme_color_override("font_color", DIM)
	_list.add_child(later)
	(swear if _sel != "" else first).grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if not _open or Time.get_ticks_msec() - _opened_ms < 250:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse") \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()

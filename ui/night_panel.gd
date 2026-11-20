class_name NightPanel
extends CanvasLayer
## Two readings of the run on one page.
##   Summary  when a camp turns the night: what that night cost and gave (foes put down, falls, countries found, parcels, the
##            level gained, the best lines of the Chronicle for that night, and a closing line chosen by how it went). Opened by
##            the camp rite (core/world/camp_rite.gd); the snapshot of the Count it measures against is kept in
##            Travel.story["night_mark"] and renewed here.
##   Credits  after the ending's card (flag credits_seen; replayable from the Chronicle page's "[R]"): the whole run read back
##            from the Chronicle, then the Count, then the first names the fire counted, then a last line. It scrolls by itself,
##            slowly; any press of interact / Esc / B leaves it; the wheel and the stick scroll it by hand.
## Pauses the night while open; built hidden at the start; the text is made once on opening (no per-frame work except the
## scroll while credits are up). Class NightPanel.

const Tally := preload("res://core/story/tally.gd")
const Days := preload("res://core/story/days.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const Danger := preload("res://core/life/encounters/danger.gd")
const Med := preload("res://ui/medieval_style.gd")
const UiSound := preload("res://ui/ui_sound.gd")

const INK := Color(0.93, 0.87, 0.74)
const DIM := Color(0.74, 0.66, 0.52)
const GILT := Color(1.0, 0.78, 0.4)
const SCROLL := 38.0

var _open := false
var _credits := false
var _was_captured := false
var _root: Control
var _title: Label
var _scroll: ScrollContainer
var _body: VBoxContainer
var _foot: Label
var _opened_ms := 0
var _acc := 0.0


func _ready() -> void:
	name = "NightPanel"
	layer = 53
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"night_panel")
	set_process(false)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var back := ColorRect.new()
	back.color = Color(0.015, 0.01, 0.01, 0.94)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.offset_left = -400.0
	col.offset_right = 400.0
	col.offset_top = -330.0
	col.offset_bottom = 330.0
	col.add_theme_constant_override("separation", 8)
	_root.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Med.gilt(_title, 34)
	col.add_child(_title)
	col.add_child(Med.rule())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	_scroll.add_child(_body)
	col.add_child(Med.rule())
	_foot = Label.new()
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foot.add_theme_font_override("font", load("res://ui/fonts/body_serif.ttf") as Font)
	_foot.add_theme_font_size_override("font_size", 15)
	_foot.add_theme_color_override("font_color", DIM)
	col.add_child(_foot)
	_root.visible = false


static func panel(tree: SceneTree) -> NightPanel:
	return tree.get_first_node_in_group(&"night_panel") as NightPanel


func _line(text: String, size := 19, color := INK, center := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://ui/fonts/body_serif.ttf") as Font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(l)


func _begin(credits: bool) -> bool:
	if _open or get_tree().paused:
		return false
	_open = true
	_credits = credits
	_opened_ms = Time.get_ticks_msec()
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_scroll.scroll_vertical = 0
	_acc = 0.0
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	set_process(false)
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UiSound.play(self, "back")


func show_summary() -> void:
	if not _begin(false):
		return
	var d := Tally.data()
	var mark: Dictionary = Travel.story.get("night_mark", {}) if Travel.story.get("night_mark") is Dictionary else {}
	var kills := int(d.get("total", 0)) - int(mark.get("total", 0))
	var falls := int(d.get("falls", 0)) - int(mark.get("falls", 0))
	var places := int(d.get("places", 0)) - int(mark.get("places", 0))
	var runs := int(d.get("runs", 0)) - int(mark.get("runs", 0))
	var camps := int(d.get("camps", 0)) - int(mark.get("camps", 0))
	var level := Danger.player_level()
	var lv0 := int(mark.get("level", level))
	_title.text = "NIGHT %d IS OVER" % maxi(1, Days.current())
	_line("What the night asked, and what it left.", 17, DIM, true)
	_line("Put down: %d.   Fallen into the dark: %d.   Countries found: %d.   Parcels carried: %d.   Camps made: %d." % [kills, falls, places, runs, camps], 20)
	if level > lv0:
		_line("Level %d to %d." % [lv0, level], 20, GILT)
	var names := Tally.latest(mini(kills, 3))
	if not names.is_empty():
		_line("The fire counted: %s." % ", ".join(names), 18)
	var lines := 0
	for e: Variant in Chronicle.entries():
		if int((e as Dictionary).get("n", 0)) == Days.current():
			_line("Night %d.  %s" % [Days.current(), String((e as Dictionary).get("t", ""))], 17, DIM)
			lines += 1
			if lines >= 8:
				break
	_line(_closing(kills, falls, places), 19, GILT, true)
	Travel.story["night_mark"] = {"total": int(d.get("total", 0)), "falls": int(d.get("falls", 0)), "places": int(d.get("places", 0)),
		"runs": int(d.get("runs", 0)), "camps": int(d.get("camps", 0)), "level": level}
	Travel.save_soon()
	_foot.text = "[%s] or [Esc] go on" % InputSetup.live_label("interact", false, "E")
	_root.visible = true
	UiSound.play(self, "tab")


func _closing(kills: int, falls: int, places: int) -> String:
	if falls >= 3:
		return "A hard night. The fire kept your place."
	if places >= 3:
		return "A night of roads. The map has more of you in it."
	if kills >= 20:
		return "A night of work. The Bearers will be busy."
	if kills == 0 and falls == 0:
		return "A quiet night. They are the ones that do not end."
	return "The night is turned. The next begins at the fire."


func show_credits() -> void:
	if not _begin(true):
		return
	var d := Tally.data()
	_title.text = "THE UMBRAL REACHES"
	_line("Your night, as the fire kept it.", 18, DIM, true)
	_line("", 30)
	for e: Variant in Chronicle.entries():
		_line("Night %d.  %s" % [int((e as Dictionary).get("n", 1)), String((e as Dictionary).get("t", ""))], 19)
	_line("", 40)
	_line("WHAT IT COST", 22, GILT, true)
	var falls := int(d.get("falls", 0))
	var camps := int(d.get("camps", 0))
	var lands := int(d.get("places", 0))
	var runs := int(d.get("runs", 0))
	var photos := int(d.get("photos", 0))
	_line("%d put down.   %d %s into the dark.   %d %s.   %d %s walked.   %d %s carried.   %d %s." % [Tally.total(), falls, "fall" if falls == 1 else "falls",
		camps, "camp" if camps == 1 else "camps", lands, "country" if lands == 1 else "countries", runs, "parcel" if runs == 1 else "parcels",
		photos, "photograph" if photos == 1 else "photographs"], 18, INK, true)
	_line("", 30)
	_line("THE FIRE REMEMBERS", 22, GILT, true)
	for n in Tally.latest(30):
		_line(String(n), 18, INK, true)
	if Tally.total() > 30:
		_line("and %d more." % (Tally.total() - 30), 17, DIM, true)
	_line("", 60)
	_line("Hearthward keeps its fire.", 26, GILT, true)
	_line("", 400)
	_foot.text = "Wheel or stick to scroll     [%s] or [Esc] leave" % InputSetup.live_label("interact", false, "E")
	_root.visible = true
	set_process(true)
	UiSound.play(self, "tab")


func _process(delta: float) -> void:
	if _open and _credits:
		_acc += delta * SCROLL
		if _acc >= 1.0:
			var whole := int(_acc)
			_acc -= float(whole)
			_scroll.scroll_vertical += whole


func _input(event: InputEvent) -> void:
	if not _open or Time.get_ticks_msec() - _opened_ms < 400:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse") or event.is_action_pressed("interact") \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()

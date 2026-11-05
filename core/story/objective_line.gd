extends VBoxContainer
## The HUD's objective tracker (top right): what the story (core/story/story.gd, group "story")
## says to do now. The story's spine first ("◆" lines), then the tracked tasks, each as a small
## block: the task's name in Cinzel, under it the step with its count ("Bone ash  3/5"), or
## "Return to ..." in lantern gold when only the turn-in is left (r33, after an MMO's quest
## tracker); the kindling count last. A changed line fades in with a lantern flash; a count that
## went up pulses. Added by ui/hud.gd (one hook line); polls the director twice a second, so it
## needs no wiring and shows nothing in a night without a story. [L] opens the ledger, where a task
## can be taken off the tracker.

const LANTERN := Color("#FFB347")
const QUIET := Color(0.8, 0.82, 0.92, 0.88)
const TITLE := Color(1.0, 0.78, 0.46, 0.92)
const UIType := preload("res://ui/type.gd")
const TextDirector := preload("res://ui/text_director.gd")

var _font: Font
var _last := ""
var _poll := 0.0
var _labels: Array[Label] = []
var _blocks: Array[Control] = []


func _ready() -> void:
	name = "Objectives"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -640
	offset_right = -44
	offset_top = 34
	offset_bottom = 420
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	_font = load("res://ui/fonts/Cinzel.ttf")


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	var story := get_tree().get_first_node_in_group("story")
	var lines: Array = story.call("objectives") if story and story.has_method("objectives") else []
	show_lines(lines)


func _label(text: String, size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	TextDirector.scaled(l, size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Draw `lines` (story.objectives()): rebuilt only when something in them changed.
func show_lines(lines: Array) -> void:
	var key := ""
	for o: Dictionary in lines:
		key += "%s#%s#%d/%d#%s|" % [String(o.get("title", "")), String(o.text), int(o.get("n", 0)), int(o.get("of", 0)), str(o.get("ready", false))]
	if key == _last:
		return
	var old := _last
	_last = key
	for b in _blocks:
		b.queue_free()
	_blocks.clear()
	_labels.clear()
	for o: Dictionary in lines:
		var fresh := old != "" and not old.contains(String(o.text))
		if bool(o.get("quest", false)):
			var box := VBoxContainer.new()
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_theme_constant_override("separation", 0)
			add_child(box)
			_blocks.append(box)
			var t := _label(String(o.get("title", "")), 17, TITLE, _font)
			box.add_child(t)
			var ready := bool(o.get("ready", false))
			var line := String(o.text)
			var of := int(o.get("of", 0))
			if of > 0:
				# the count goes at the end, MMO-tracker style; the step's own "(n/of)" comes out
				line = line.replace(" (%d/%d)" % [int(o.get("n", 0)), of], "")
				line += "   %d/%d" % [int(o.get("n", 0)), of]
			var s := _label(("›  " if not ready else "✓  ") + TextDirector.sentence(line), 18, LANTERN if ready else QUIET, UIType.body())
			box.add_child(s)
			_labels.append(s)
			if fresh:
				_flash(box)
			elif of > 0 and old != "" and not old.contains("#%d/%d#" % [int(o.get("n", 0)), of]):
				_pulse(s)
		else:
			# r37: a sentence is body text in sentence case; Cinzel stays on the task names above
			var l := _label(("◆  " if o.main else "◇  ") + TextDirector.sentence(String(o.text)), 21 if o.main else 19, QUIET, UIType.body())
			add_child(l)
			_blocks.append(l)
			_labels.append(l)
			if fresh:
				_flash(l)


func _flash(c: Control) -> void:
	c.modulate = Color(LANTERN.r, LANTERN.g, LANTERN.b, 0.0)
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color(1.4, 1.1, 0.8, 1.0), 0.6)
	tw.tween_property(c, "modulate", Color.WHITE, 1.4)


func _pulse(c: Control) -> void:
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color(1.5, 1.2, 0.8, 1.0), 0.15)
	tw.tween_property(c, "modulate", Color.WHITE, 0.8)


func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for l in _labels:
		out.append(l.text)
	return out

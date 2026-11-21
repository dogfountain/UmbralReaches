extends VBoxContainer
## The HUD's objective tracker (top right): what the story (core/story/story.gd, group "story")
## says to do now. The story's spine first ("◆" lines), then the tracked tasks, each as a small
## block: the task's name in Cinzel, under it the step with its count ("Bone ash  3/5"), or
## "Return to ..." in lantern gold when only the turn-in is left (r33, after an MMO's quest
## tracker); the kindling count last. A changed line fades in with a lantern flash; a count that
## went up pulses. Added by ui/hud.gd (one hook line); polls the director twice a second, so it
## needs no wiring and shows nothing in a night without a story. [L] opens the ledger, where Track picks
## the one task followed (core/story/quest_track.gd: its block is the one shown, behind its painted pin).

const TickPhase := preload("res://core/util/tick_phase.gd")
const LANTERN := Color("#FFB347")
const QUIET := Color(0.8, 0.82, 0.92, 0.88)
const TITLE := Color(1.0, 0.78, 0.46, 0.92)
const UIType := preload("res://ui/type.gd")
const Access := preload("res://ui/access.gd")
const TextDirector := preload("res://ui/text_director.gd")
const Guide := preload("res://core/story/guide.gd")
const QuestTrack := preload("res://core/story/quest_track.gd")

var _font: Font
var _last := ""
var _poll := 0.0
var _labels: Array[Label] = []
var _blocks: Array[Control] = []


func _ready() -> void:
	_poll = TickPhase.first(self, 0.5)
	name = "Objectives"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -640
	offset_right = -44
	offset_top = 86                       # under the compass strip (it ends at 82), not behind it
	offset_bottom = 420
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	_font = load("res://ui/fonts/Cinzel.ttf")


func _process(delta: float) -> void:
	_fade_tick(delta)
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = TickPhase.next(_poll, 0.5)
	var story := get_tree().get_first_node_in_group("story")
	var lines: Array = story.call("objectives") if story and story.has_method("objectives") else []
	show_lines(lines)


## the tracker shows for SHOW_S seconds when what it says changes, then hides; holding the
## "show_objective" action (Y, View) brings it back. It also stands aside while a banner is up
## (the text director's banner lane) and while the HUD is still holding a new game's opening.
const SHOW_S := 6.0
var _show_t := 0.0


func _fade_tick(delta: float) -> void:
	var hud := get_tree().get_first_node_in_group(&"hud")
	var held: bool = hud != null and hud.has_method("staged_in") and not bool(hud.call("staged_in"))
	if not held and not get_tree().paused:
		_show_t = maxf(0.0, _show_t - delta)
	# a guided first act keeps it up: the next step is always on screen (core/story/guide.gd)
	var want := _show_t > 0.0 or Input.is_action_pressed("show_objective") or Guide.on()
	var td := TextDirector.of(self)
	if td != null and td.banner_up():
		want = false
	modulate.a = move_toward(modulate.a, 1.0 if want else 0.0, delta * (4.0 if want else 1.6))


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
		key += "%s#%s#%d/%d#%s#%s|" % [String(o.get("title", "")), String(o.text), int(o.get("n", 0)), int(o.get("of", 0)), str(o.get("ready", false)),
			"" if bool(o.get("quest", false)) else _mark_of(o)]
	if key == _last:
		return
	var old := _last
	_last = key
	_show_t = SHOW_S
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
			# the followed task's name, behind its painted pin (the same mark the waypoint and the compass wear)
			var head := HBoxContainer.new()
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			head.alignment = BoxContainer.ALIGNMENT_END
			head.add_theme_constant_override("separation", 8)
			var t := _label(String(o.get("title", "")), 17, TITLE, _font)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(t)
			var pin := TextureRect.new()
			pin.texture = IconArt.art("mark", "followed")
			pin.custom_minimum_size = Vector2(24, 24)
			pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			head.add_child(pin)
			box.add_child(head)
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
			# a sentence is body text in sentence case; Cinzel stays on the task names above. The spine's lines end in
			# a painted mark (the guide's kind of place for the step it points at, else a task's), not a glyph
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.alignment = BoxContainer.ALIGNMENT_END
			row.add_theme_constant_override("separation", 10)
			var l := _label(TextDirector.sentence(String(o.text)), 21 if o.main else 19, QUIET, UIType.body())
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var ic := TextureRect.new()
			ic.texture = IconArt.art("mark", _mark_of(o))
			ic.custom_minimum_size = Vector2(30, 30) if o.main else Vector2(24, 24)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not o.main:
				ic.modulate = Color(1, 1, 1, 0.8)
			row.add_child(ic)
			add_child(row)
			_blocks.append(row)
			_labels.append(l)
			if fresh:
				_flash(row)


## The painted mark at the end of a spine line: the followed step wears the kind of place it points at.
func _mark_of(o: Dictionary) -> String:
	if not bool(o.main):
		return "fire" if String(o.get("id", "")) == "kindle" else "quest_target"
	var tr := get_tree().get_first_node_in_group("quest_track") as QuestTrack
	var st: Dictionary = tr.current() if tr != null else {}
	if String(st.get("key", "")) == String(o.get("id", "")):
		return String(st.get("art", "quest_target"))
	return "quest_target"


func _flash(c: Control) -> void:
	c.modulate = Color(LANTERN.r, LANTERN.g, LANTERN.b, 0.0)
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color.WHITE.lerp(Color(1.4, 1.1, 0.8, 1.0), Access.flash()), 0.6)
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

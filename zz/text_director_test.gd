extends Node
## The text arbiter (ui/text_director.gd): lanes, priorities, the busy rule, the 90 s discovery limit.
## Fails when two lanes draw in the same rectangle on any frame, or two banners come within 90 s.
## No world: a bare director on a Control, driven with synthetic frames (tick(dt)).
##   HOME=<scratch> godot --headless --path . res://zz/text_director_test.tscn
const TextDirector := preload("res://ui/text_director.gd")
var bad := 0
var td: Node
var frames := 0
var clash := ""


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	td = TextDirector.new()
	add_child(td)
	td.set_process(false)             # the test is the clock
	td.build(root, null)
	td.test_set(false, false)
	_priorities()
	await _storm()
	await _busy()
	_limit()
	_scale()
	print("TEXT_DIRECTOR done bad=%d (frames checked %d)" % [bad, frames])
	get_tree().quit(1 if bad > 0 else 0)


func _step(dt := 0.1) -> void:
	td.tick(dt)
	frames += 1
	var o: String = td.overlap()
	if o != "" and clash == "":
		clash = o
		_ok(false, "two lanes drew in the same rectangle: %s (frame %d)" % [o, frames])


func _run(seconds: float) -> void:
	for i in int(seconds / 0.1):
		_step()


func _priorities() -> void:
	_ok(td.can_begin(&"toast") and td.can_begin(&"discovery") and td.can_begin(&"lesson"), "an idle screen lets everything begin")
	_ok(td.begin(&"lesson", 3.0), "a lesson begins")
	_ok(not td.can_begin(&"narration") == false, "narration may take the lane from a lesson")
	var bumped: Array = []
	td.bumped.connect(func(k: StringName) -> void: bumped.append(k))
	_ok(td.begin(&"narration", 2.0), "narration begins over the lesson")
	_ok(bumped == [&"lesson"], "...and the lesson was bumped (%s)" % [bumped])
	_ok(not td.can_begin(&"discovery") and not td.can_begin(&"toast") and not td.can_begin(&"title"), "while narration is up, banners and toasts queue")
	_ok(not td.can_begin(&"lesson"), "...and a lesson queues behind it")
	td.end(&"narration")
	_ok(td.can_begin(&"discovery"), "narration over: a discovery may begin")
	td.begin(&"discovery", 5.0)
	_ok(not td.can_begin(&"quest") and not td.can_begin(&"title") == false, "a banner is one at a time; a title card outranks a discovery")
	_ok(td.can_begin(&"lesson"), "a lesson (higher) is not held by a banner")
	td.end(&"discovery")
	td.begin(&"title", 6.0, Rect2(300, 200, 1100, 280), true)
	bumped.clear()
	td.begin(&"boss_title", 3.4, Rect2(300, 206, 1400, 150), true)
	_ok(bumped == [&"title"] and not td.is_up(&"title") and td.is_up(&"boss_title"), "a boss title takes the banner lane from the zone card (%s)" % [bumped])
	_ok(not td.can_begin(&"discovery") and not td.can_begin(&"title") and not td.can_begin(&"quest"), "...and no card or banner starts under it")
	td.end(&"boss_title")
	td.begin(&"boss_emote", 1.0, Rect2(300, 168, 900, 60), true)
	_ok(not td.can_begin(&"lesson"), "a boss emote outranks a lesson")
	td.end(&"boss_emote")
	td.test_set(false, true)
	_ok(not td.can_begin(&"toast") and not td.can_begin(&"discovery") and td.can_begin(&"lesson"), "locked on: only lessons (and emotes) draw")
	td.test_set(false, false)
	for k: StringName in [&"lesson", &"discovery"]:
		td.end(k)


## 300 s of everything at once, every frame checked for two lanes in one rectangle.
func _storm() -> void:
	var t := 0.0
	var disc_pending := 0
	var gaps_bad := 0
	td.banner_log.clear()
	for i in 3000:
		t += 0.1
		if i % 17 == 0:
			td.post_toast("Toast number %d with a fair amount of words to wrap about" % i)
		if i % 71 == 0:
			td.post_lesson("A lesson line, number %d" % i)
		if i % 23 == 0:
			disc_pending += 1
		if i % 313 == 0:
			td.begin(&"narration", 4.0)
		if i % 400 == 0 and td.can_begin(&"quest"):
			td.begin(&"quest", 5.0)
		if i % 500 == 0:
			td.begin(&"boss_emote", 5.0, Rect2(300, 168, 900, 60), true)
		if i % 47 == 0 and disc_pending > 0 and td.can_begin(&"discovery"):
			disc_pending -= 1
			if td.discovery_ok():
				td.begin(&"discovery", 6.0)
			else:
				td.quiet("Somewhere new")
		_step()
	for i in range(1, td.banner_log.size()):
		if float(td.banner_log[i]) - float(td.banner_log[i - 1]) < 90.0 - 0.001:
			gaps_bad += 1
	_ok(td.banner_log.size() >= 2 and gaps_bad == 0, "no two discovery banners within 90 s (%d banners in 300 s, %d too close)" % [td.banner_log.size(), gaps_bad])
	_ok(td.banner_log.size() <= 4, "at most four banners in 300 s (got %d)" % td.banner_log.size())
	_run(30.0)


func _busy() -> void:
	for t in 100:
		_step()
	var before: int = td.drawn().size()
	td.begin(&"narration", 3.0)
	td.post_toast("A toast during the narration")
	_run(1.5)
	var shown := false
	for d: Dictionary in td.drawn():
		if d.kind == &"toast":
			shown = true
	_ok(not shown, "a toast queues while narration is up")
	td.end(&"narration")
	_run(3.0)
	shown = false
	for d: Dictionary in td.drawn():
		if d.kind == &"toast":
			shown = true
	_ok(shown, "...and shows once it is over (%d drawn before)" % before)
	# at most two toasts at once
	_run(10.0)
	for i in 6:
		td.post_toast("Stacked toast %d" % i)
	_run(0.6)
	var n := 0
	for d: Dictionary in td.drawn():
		if d.kind == &"toast":
			n += int(d.count)
	_ok(n <= 2, "two toasts at most on screen (%d)" % n)
	# a dialogue box up: the same
	_run(20.0)
	td.test_set(true, false)
	td.post_toast("During a conversation")
	_run(1.0)
	_ok(not td.can_begin(&"discovery") and td.queued() >= 1, "a dialogue box holds banners and toasts")
	td.test_set(false, false)
	_run(20.0)


func _limit() -> void:
	_ok(td.discovery_ok() or td.banner_log.size() > 0, "discovery_ok answers")
	td.tick(100.0)
	_ok(td.discovery_ok(), "after 100 s a banner may draw again")
	td.begin(&"discovery", 1.0)
	_ok(not td.discovery_ok(), "...and right after one, none may")
	td.tick(89.0)
	_ok(not td.discovery_ok(), "89 s later, still none")
	td.tick(1.5)
	_ok(td.discovery_ok(), "90 s later, one may")


func _scale() -> void:
	var before := TextDirector.px(20)
	Settings.text_scale = 1.5
	_ok(TextDirector.px(20) == 30, "Text Scale 1.5 makes a 20 px line 30 px (%d, was %d)" % [TextDirector.px(20), before])
	Settings.text_scale = 0.85
	_ok(TextDirector.px(20) == 17, "Text Scale 0.85 makes it 17 px")
	Settings.text_scale = 1.0
	_ok(TextDirector.sentence("NEW TASK") == "New task" and TextDirector.sentence("The Keep") == "The Keep", "all-capitals text is set in sentence case")


func _ok(cond: bool, what: String) -> void:
	print(("TEXT_DIRECTOR ok   " if cond else "TEXT_DIRECTOR FAIL ") + what)
	if not cond:
		bad += 1

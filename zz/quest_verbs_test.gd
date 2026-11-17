extends Node
## The task verbs, headless (docs/QUEST_VERBS.md): godot --headless --path . res://zz/quest_verbs_test.tscn
## clues (read, remembered, qc:, the step moves on at `need`), tracks (marks one at a time, the area of the next),
## order (right counts, wrong resets and wakes a foe, all right moves on), lantern_walk (out = a step back),
## vigil (a defend with no ward: the clock, the gloom rate, waves that go for the wanderer), the data audit, and
## a save round trip of the verbs' state. Ends: VERBS PASS / VERBS FAIL n
## Holds Travel._busy (no save) and puts Travel.story back after.

const Chains := preload("res://core/story/quest_chains.gd")
const Book := preload("res://core/story/quest_book.gd")
const QuestDB := preload("res://core/story/quest_db.gd")
const Runner := preload("res://core/story/quest_runner.gd")
const VerbKit := preload("res://core/story/verb_kit.gd")
const VerbWorld := preload("res://core/story/verb_world.gd")
const Defend := preload("res://core/story/defend.gd")

var bad := 0
var runner: Node
var verbs: Node


func ok(c: bool, what: String) -> void:
	print(("VERBS ok   " if c else "VERBS FAIL ") + what)
	if not c:
		bad += 1


func _init() -> void:
	Engine.set_meta(&"full_night", true)


func _ready() -> void:
	Travel._busy = true
	var story0: Dictionary = Travel.story.duplicate(true)
	Travel.story = {}
	Book.quiet = true
	runner = Runner.new()
	add_child(runner)
	VerbWorld.prepare(func(near: Vector2, _r: float) -> Vector3: return Vector3(near.x, 0.0, near.y))
	verbs = VerbWorld.new()
	add_child(verbs)
	_floor()
	await get_tree().process_frame
	_data()
	await _clues()
	await _tracks()
	await _order()
	_lantern()
	await _vigil()
	Book.quiet = false
	Travel.story = story0
	print("VERBS %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	get_tree().quit(0 if bad == 0 else 1)


func _floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 2.0, 600.0)
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector3(0.0, -1.0, 0.0)


func _data() -> void:
	ok(Chains.audit().is_empty(), "the quest audit is clean %s" % [Chains.audit()])
	var kinds := {}
	for id: String in Chains.ORDER:
		for s: Dictionary in Chains.QUESTS[id].steps:
			kinds[String(s.kind)] = true
	for k: String in VerbKit.KINDS:
		ok(kinds.has(k), "a task in the book uses %s" % k)
	var tr: Dictionary = Chains.step("slow_way", 0)
	var inside := true
	for i in (tr.marks as Array).size():
		var a := VerbKit.area("slow_way", tr, {"n": i})
		var at: Vector2 = (tr.marks[i] as Dictionary).at
		inside = inside and at.distance_to(a.c as Vector2) < float(a.r) * 0.5 and (a.c as Vector2) != at
	ok(inside, "a trail's area holds its next mark and is not centred on it")
	ok(VerbKit.area("slow_way", tr, {"n": 1}).c == VerbKit.area("slow_way", tr, {"n": 1}).c, "the area is the same every time")
	var bad_step := {"kind": "clues", "clues": [{"key": "a:b", "at": Vector2.ZERO, "text": "x"}], "need": 3}
	ok(not VerbKit.audit("t", 0, bad_step).is_empty(), "the audit refuses a clue with a : in its key, no area and too large a need")
	ok(QuestDB.audit_cond("qc:keg_thief:prints,!qc:keg_thief:gnaw") == "", "qc: is a condition term")


func _clues() -> void:
	Book.start("keg_thief")
	await get_tree().process_frame
	await get_tree().process_frame
	ok(int((verbs.call("info") as Dictionary).nodes.size()) == 4, "four signs stand behind the Keg")
	ok(not QuestDB.test("qc:keg_thief:gnaw", {}), "nothing is known before it is read")
	ok(bool(verbs.call("examine", "keg_thief", "gnaw")) and Book.step("keg_thief") == 0, "one sign read: the step stays")
	ok(QuestDB.test("qc:keg_thief:gnaw,!qc:keg_thief:prints", {}), "a red herring is remembered like any clue")
	verbs.call("examine", "keg_thief", "gnaw")
	ok(VerbKit.clue_count(Chains.step("keg_thief", 0), Book.q("keg_thief"))[0] == 1, "reading one twice counts once")
	ok(Chains.step_text("keg_thief", 0, Book.q("keg_thief")).contains("(1/2 read)"), "the objective counts what was read")
	ok(not bool(verbs.call("examine", "keg_thief", "nothing")), "a sign that is not there is refused")
	verbs.call("examine", "keg_thief", "latch")
	ok(Book.step("keg_thief") == 1, "the second sign moves the task on (%d)" % Book.step("keg_thief"))
	ok(QuestDB.test("qc:keg_thief:latch,qc:keg_thief:gnaw,!qc:keg_thief:circle", {}), "what was read stays remembered after the step")
	# saved with the task: a round trip through JSON keeps it
	var copy: Dictionary = JSON.parse_string(JSON.stringify(Travel.story))
	ok(((copy.quests as Dictionary).keg_thief.f as Dictionary).has("c:latch"), "the clue is in the saved task")
	Book.drop("keg_thief")
	await get_tree().process_frame
	await get_tree().process_frame
	ok((verbs.call("info") as Dictionary).nodes.is_empty(), "set aside: nothing stands")


func _tracks() -> void:
	Book.start("slow_way")
	await get_tree().process_frame
	await get_tree().process_frame
	var info: Dictionary = verbs.call("info")
	ok(info.nodes.size() == 1 and info.track == 1, "only the next mark stands")
	var a0 := VerbKit.area("slow_way", Chains.step("slow_way", 0), Book.q("slow_way"))
	verbs.call("_reveal", "slow_way", 1)
	ok(Book.noted("slow_way", "n") == 0, "a mark out of turn is not read")
	verbs.call("_reveal", "slow_way", 0)
	ok(Book.noted("slow_way", "n") == 1 and Book.step("slow_way") == 0, "the first mark read: the second is revealed")
	ok(VerbKit.area("slow_way", Chains.step("slow_way", 0), Book.q("slow_way")).c != a0.c, "the area moves to the next mark")
	ok(Chains.step_text("slow_way", 0, Book.q("slow_way")).contains("(1/4)"), "the objective counts the marks")
	verbs.call("_reveal", "slow_way", 1)
	verbs.call("_reveal", "slow_way", 2)
	verbs.call("_reveal", "slow_way", 3)
	ok(Book.step("slow_way") == 1, "the last mark ends the step")
	Book.drop("slow_way")


func _order() -> void:
	Book.start("drowned_bell")
	Book.advance("drowned_bell")
	await get_tree().process_frame
	await get_tree().process_frame
	ok(Chains.step("drowned_bell", Book.step("drowned_bell")).kind == "order", "on the order step")
	ok(not bool(verbs.call("touch", "drowned_bell", "choir")), "the second slate first is wrong")
	ok(int((verbs.call("info") as Dictionary).foes) == 1, "a wrong touch woke a foe")
	ok(bool(verbs.call("touch", "drowned_bell", "ferryman")) and Book.noted("drowned_bell", "o") == 1, "the first slate counts")
	ok(bool(verbs.call("touch", "drowned_bell", "choir")) and Book.noted("drowned_bell", "o") == 2, "the second counts")
	ok(not bool(verbs.call("touch", "drowned_bell", "ferryman")) and Book.noted("drowned_bell", "o") == 0, "a wrong one in the middle starts it again")
	for k: String in ["ferryman", "choir", "child"]:
		verbs.call("touch", "drowned_bell", k)
	ok(Book.step("drowned_bell") == 2, "all three in order: on to the tongue")
	await get_tree().process_frame
	await get_tree().process_frame
	ok(int((verbs.call("info") as Dictionary).foes) == 0, "the foes it woke are cleared when the step is over")
	Book.drop("drowned_bell")


func _lantern() -> void:
	Book.start("spire_lamps")
	Book.advance("spire_lamps")
	runner.call("check")
	var lw: Node = (runner.get("_enc") as Dictionary).get("spire_lamps")
	ok(lw != null and Book.step("spire_lamps") == 1, "the runner stands the lamp up on its step")
	if lw == null:
		return
	lw.set("_age", 1.0)
	lw.call("_out", "A blow.")
	ok(Book.step("spire_lamps") == 0, "the flame out: the task falls back to lighting it")
	Book.drop("spire_lamps")


func _vigil() -> void:
	Book.start("alms_loaf")
	Book.advance("alms_loaf", 2)
	var hitter := Node3D.new()
	hitter.add_to_group(Groups.PLAYER)
	add_child(hitter)
	var stp: Dictionary = Chains.step("alms_loaf", 2)
	hitter.global_position = Vector3((stp.at as Vector2).x, 0.0, (stp.at as Vector2).y)
	runner.call("check")
	var d: Defend = (runner.get("_enc") as Dictionary).get("alms_loaf") as Defend
	ok(d != null and d.max_hp == 1.0, "the runner stands the vigil up: a defend with nothing to hurt")
	if d == null:
		return
	ok(not d.threat_alive(), "foes are never sent at it: they want the wanderer")
	d.tick(15.0)
	ok(d.time_left < 31.0 and not d.foes.is_empty(), "the clock runs while she keeps the place, and the first wave came (%d)" % d.foes.size())
	ok(d.foes[0].ward == null, "the wave goes for the wanderer, not a ward")
	hitter.global_position += Vector3(30.0, 0.0, 0.0)
	var before := d.time_left
	d.tick(5.0)
	ok(d.away and is_equal_approx(d.time_left, before), "the clock stops while she is away")
	hitter.global_position -= Vector3(30.0, 0.0, 0.0)
	d.tick(60.0)
	ok(d.done and Book.step("alms_loaf") == 3, "the hour kept: the task moves on")
	hitter.queue_free()
	Book.drop("alms_loaf")

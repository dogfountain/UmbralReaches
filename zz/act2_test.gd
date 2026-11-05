extends Node
## r36 Act II, the Founder's peal (docs/critique/r36_plan.md), headless, no world:
##   godot --headless --path . res://zz/act2_test.tscn
## The data hangs together (seven bells, one per far country, each with its giver, keeper, bell and
## conversation); bells count when answered for, rung or carried; the summit ward and the Warden's
## arena stay shut to heart and crown alone; the Ward on the Crossing waits for Brannoc's peal; the
## Warden loses a share of his life for every tongue carried home.
## Holds Travel._busy (no save) and puts Travel.story back after. Ends: ACT2 PASS / ACT2 FAIL n

const Chains := preload("res://core/story/quest_chains.gd")
const Book := preload("res://core/story/quest_book.gd")
const QuestDB := preload("res://core/story/quest_db.gd")
const DialogueDB := preload("res://core/story/dialogue_db.gd")
const Warden := preload("res://core/enemy/ascended_warden.gd")

var bad := 0


func ok(c: bool, what: String) -> void:
	print(("ACT2 ok   " if c else "ACT2 FAIL ") + what)
	if not c:
		bad += 1


func _ready() -> void:
	Travel._busy = true
	var story0: Dictionary = Travel.story.duplicate(true)
	var bosses0: Dictionary = Travel.bosses_slain.duplicate()
	Travel.story = {}
	Travel.bosses_slain.clear()
	_data()
	_counting()
	_gates()
	_act3()
	Travel.story = story0
	Travel.bosses_slain = bosses0
	print("ACT2 %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	get_tree().quit(0 if bad == 0 else 1)


func _data() -> void:
	ok(Chains.audit().is_empty(), "the quest audit is clean %s" % [Chains.audit()])
	ok(DialogueDB.audit().is_empty(), "the dialogue audit is clean %s" % [DialogueDB.audit()])
	ok(Chains.BELLS.size() == 7 and Chains.BELL_KEEPERS.size() == 7, "seven bells, seven keepers")
	var zones := {}
	var rares: Dictionary = (load("res://core/enemy/rares.gd") as Script).get_script_constant_map().get("RARES", {})
	for i in Chains.BELLS.size():
		var id := String(Chains.BELLS[i])
		var qd: Dictionary = Chains.QUESTS[id]
		zones[String(qd.zone)] = true
		ok(Chains.ORDER.has(id), "%s is in the ledger's order" % id)
		ok(String(qd.avail).contains("q:founders_peal"), "%s waits for Brannoc's ask" % id)
		var keeper := String((qd.steps[0] as Dictionary).get("rares", [""])[0])
		ok(keeper == Chains.BELL_KEEPERS[i] and rares.has(keeper), "%s: its keeper %s walks the realm" % [id, keeper])
		var keys := Chains.gather_keys(id, 1)
		ok(keys.size() == 1 and (Chains.PICKUPS[keys[0]] as Dictionary).has("conv"), "%s: one bell, which asks" % id)
		if keys.size() == 1:
			var conv := String(Chains.PICKUPS[keys[0]].conv)
			ok(DialogueDB.CONV.has(conv), "%s: its conversation exists" % id)
			var at: Dictionary = DialogueDB.node(conv, "at")
			ok((at.get("choices", []) as Array).size() == 3, "%s: ring it, carry it, or leave it" % id)
		var outs: Dictionary = qd.get("outcome", {})
		ok(outs.has("rung") and outs.has("carried"), "%s: an ending for each choice" % id)
		# the keeper's haunt is the bell's: the bounty's pin is the bell
		var pk: Vector2 = Chains.PICKUPS[keys[0]].near if keys.size() == 1 else Vector2.INF
		var spot: Vector2 = (rares.get(keeper, {}) as Dictionary).get("spots", [Vector2.ZERO])[0]
		ok(pk.distance_to(spot) < 8.0, "%s: the keeper haunts its bell (%.1f m)" % [id, pk.distance_to(spot)])
	ok(zones.size() == 7, "one bell in each far country (%s)" % [zones.keys()])


func _counting() -> void:
	ok(Book.bells() == 0, "no bells to begin with")
	Book.start("bell_holds")
	Book.choose("bell_holds", "rung")
	Book.start("bell_mere")
	Book.choose("bell_mere", "carried")
	ok(Book.bells() == 2 and Book.bells_carried() == 1, "a rung bell and a carried one both count; one hangs at the Keg")
	ok(not QuestDB.test("bells:4", {}), "two bells are not a peal")
	Book.start("founders_peal")
	ok(Chains.step_text("founders_peal", 0, Book.q("founders_peal")).contains("2 of 7"), "Brannoc's step counts them: %s" % Chains.step_text("founders_peal", 0, Book.q("founders_peal")))
	for id: String in ["bell_quarry", "bell_moor"]:
		Book.start(id)
		Book.choose(id, "carried")
	ok(QuestDB.test("bells:4", {}), "four bells are a peal")
	ok(Book.bells_carried() == 3, "three tongues at the Keg")


func _gates() -> void:
	# the ward on the Crossing: heart and crown alone do not open it
	var ward := WardSeal.new()
	ward.requires_bells = Chains.BELLS_NEEDED
	ward.requires_bosses = ["thornwarden", "bone_abbot"]
	Travel.bosses_slain["thornwarden"] = true
	Travel.bosses_slain["bone_abbot"] = true
	ok(ward.bosses_ok(), "heart, crown and four bells: the ward will open")
	Travel.story = {}
	ok(not ward.bosses_ok(), "heart and crown, no bells: the ward stays shut")
	ward.free()
	ok(BossArena.no_peal(0, 4).begins_with("Nothing answers."), "the dais says why: %s" % BossArena.no_peal(0, 4))
	ok(BossArena.no_peal(2, 4).contains("2") and BossArena.no_peal(2, 4).contains("4"), "and how far: %s" % BossArena.no_peal(2, 4))
	# the Crossing's task waits for the peal
	var avail := String(Chains.QUESTS["crossing_ward"].avail)
	var ws := {"bosses": Travel.bosses_slain}
	ok(not QuestDB.test(avail, ws), "the Ward on the Crossing is not offered before the peal")
	Book.start("founders_peal")
	Book.complete("founders_peal")
	ok(QuestDB.test(avail, ws), "and is once Brannoc has his peal")
	# the Warden holds less for every tongue carried home (all seven: about a third)
	ok(is_equal_approx(Warden.BELL_HOLD * 7.0, 0.35), "seven tongues cost the Warden 35% of his life")
	ok(Warden.BELL_WORDS.size() == 8, "a word for every count of bells")


## r36 Act III: the door, those still climbing, the names, the full peal; the valley after.
func _act3() -> void:
	const Reach := preload("res://core/world/night/reach_state.gd")
	for id: String in ["the_latch", "still_climbing", "names_under", "full_peal"]:
		ok(Chains.QUESTS.has(id) and Chains.ORDER.has(id), "Act III: %s is in the ledger" % id)
	ok(String(Chains.QUESTS.the_latch.avail).contains("boss:ascended_warden"), "the latch waits for the Warden")
	var at: Dictionary = DialogueDB.node("door_latch", "at")
	ok((at.get("choices", []) as Array).size() == 4, "at the door: latch it, leave it on the latch, break it, or not yet")
	ok(Chains.gather_keys("names_under", 0).size() == 4, "four names from four far fires")
	Travel.story = {}
	Travel.bosses_slain["ascended_warden"] = true
	ok(Reach.act() == 4, "act 4 after the Warden")
	for id: String in ["the_latch", "still_climbing", "names_under"]:
		Book.start(id)
	Book.choose("the_latch", "latched")
	for id: String in ["the_latch", "still_climbing", "names_under"]:
		Book.complete(id)
	ok(Reach.act() == 5 and Reach.pressure() < 1.0, "a latched door: act 5, and the dark presses less (%.1f)" % Reach.pressure())
	Book.choose("the_latch", "open")
	ok(Reach.homecoming() and Reach.pressure() == 1.0, "a door on the latch: the ones above come home")
